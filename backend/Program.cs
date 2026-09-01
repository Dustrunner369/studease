using System.Text.RegularExpressions;
using System.Threading.RateLimiting;
using study_spot_backend;
using study_spot_backend.Dtos;
using study_spot_backend.Models;
using study_spot_backend.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);

// Middleware
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        if (builder.Environment.IsDevelopment())
        {
            // Flutter web and the Angular dev server come from whatever port the
            // tooling picks, so don't fight it locally.
            policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
        }
        else
        {
            policy.WithOrigins("http://localhost:4200")
                .AllowAnyHeader()
                .AllowAnyMethod();
        }
    });
});

var connectionString = NormalizeConnectionString(
    builder.Configuration.GetConnectionString("DefaultConnection"));
var migrationConnectionString = NormalizeConnectionString(
    builder.Configuration.GetConnectionString("Migrations")) ?? connectionString;

builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseNpgsql(connectionString).UseSnakeCaseNamingConvention());
builder.Services.AddDatabaseDeveloperPageExceptionFilter();
builder.Services.AddHttpClient<PlacesClient>();
builder.Services.AddSingleton<FeedbackMailer>();
builder.Services.AddProblemDetails();

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

var firebaseProjectId = builder.Configuration["Auth:FirebaseProjectId"];

// Dev only, and only when explicitly asked for. Two conditions, not one: an env var
// alone must never be enough to disable auth on a deployed instance.
var allowDevBypass = builder.Environment.IsDevelopment()
    && builder.Configuration.GetValue<bool>("Auth:AllowDevBypass");

const string DevOrBearerScheme = "DevOrBearer";

var authBuilder = builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = allowDevBypass ? DevOrBearerScheme : JwtBearerDefaults.AuthenticationScheme;
    options.DefaultAuthenticateScheme = options.DefaultScheme;
    options.DefaultChallengeScheme = options.DefaultScheme;
});

authBuilder.AddJwtBearer(options =>
{
    // Firebase publishes an OIDC discovery document here, so JwtBearer fetches and
    // caches the signing keys itself and rotates them without a restart.
    options.Authority = $"https://securetoken.google.com/{firebaseProjectId}";
    options.Audience = firebaseProjectId;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidIssuer = $"https://securetoken.google.com/{firebaseProjectId}",
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        // Set timer to 30 seconds instead of 5 minute default  
        ClockSkew = TimeSpan.FromSeconds(30),
    };
});

if (allowDevBypass)
{
    authBuilder.AddScheme<AuthenticationSchemeOptions, DevBypassAuthHandler>("DevBypass", _ => { });

    // A real bearer token still gets validated as a real token; only requests with no
    // Authorization header at all fall back to the seeded dev user.
    authBuilder.AddPolicyScheme(DevOrBearerScheme, DevOrBearerScheme, options =>
    {
        options.ForwardDefaultSelector = context =>
            context.Request.Headers.ContainsKey("Authorization")
                ? JwtBearerDefaults.AuthenticationScheme
                : "DevBypass";
    });
}

builder.Services.AddAuthorization();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<CurrentUser>();

// Nothing had any throttling before this - fine while only I was hitting it, not once
// /feedback started sending real email to my own inbox. Partitioned by IP rather than
// by user: it needs to also cover the public /privacy.html and /support.html pages
// (served before auth even runs), and a per-user partition would need the JWT already
// resolved, which isn't guaranteed this early in the pipeline.
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    string ClientKey(HttpContext ctx) => ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";

    // Generous backstop for the whole API - real usage should never come close to this,
    // it's just a floor against basic scripted abuse.
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
        RateLimitPartition.GetFixedWindowLimiter(ClientKey(ctx), _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 120,
            Window = TimeSpan.FromMinutes(1),
        }));

    // Feedback sends a real email to my own inbox now - the one endpoint where abuse has
    // a direct external consequence, so it gets a tighter policy on top of the global one.
    options.AddPolicy("feedback", ctx =>
        RateLimitPartition.GetFixedWindowLimiter(ClientKey(ctx), _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 5,
            Window = TimeSpan.FromHours(1),
        }));
});

var app = builder.Build();

if (allowDevBypass)
{
    app.Logger.LogWarning(
        "Auth:AllowDevBypass is ON - unauthenticated requests are treated as the seeded " +
        "dev user. Never enable this outside Development.");
}

// Automatically applies any database migrations at runtime.
// NOTE: fine while this is a one-person project, but this means a container restart
// runs whatever migration shipped in the image — including a destructive one. Make it
// a deliberate step before anyone else's data is in here.
// Runs over ConnectionStrings:Migrations (Neon's direct/unpooled connection) rather than
// the app's pooled one - PgBouncer's transaction pooling doesn't reliably support the
// advisory locks and session state EF's migrator relies on.
var migrationOptions = new DbContextOptionsBuilder<AppDbContext>()
    .UseNpgsql(migrationConnectionString)
    .UseSnakeCaseNamingConvention()
    .Options;
using (var migrationContext = new AppDbContext(migrationOptions))
{
    migrationContext.Database.Migrate();
}

app.UseCors();

// Early on purpose - applies to literally every request, including the public static
// pages below and anything that never makes it past authentication.
app.UseRateLimiter();

// Serves wwwroot/privacy.html at /privacy.html - the public, unauthenticated page App
// Store Connect's Privacy Policy URL field links to. Placed before auth so it's never
// gated behind a token; context/privacy-policy.md is the source of truth, kept in sync
// with this file and the in-app PrivacyPolicyPage by hand.
app.UseStaticFiles();

app.UseAuthentication();
app.UseAuthorization();

// Every endpoint needs a valid token (or the dev bypass); `registered` additionally
// needs an actual users row, which every guest already has (see CurrentUser).
var api = app.MapGroup("").RequireAuthorization();
var registered = api.MapGroup("").AddEndpointFilter<RequireRegisteredFilter>();

const int guestEntryLimit = 3;

// ---------------------------------------------------------------------------
// Places
// ---------------------------------------------------------------------------

// Proxies Places Autocomplete so the API key never ships inside a client. Authenticated
// but not behind RequireRegisteredFilter - it's a metered Google API, not user data, and
// an unauthenticated version of this endpoint would be someone else's free Places quota.
api.MapGet("/places/search", async (string? q, PlacesClient places, CancellationToken ct) =>
{
    if (!places.IsConfigured)
    {
        return Results.Problem(
            title: "Places search is not configured",
            detail: "Set Places:ApiKey (or the Places__ApiKey environment variable) to enable " +
                    "search. Spots can still be added manually in the meantime.",
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    if (string.IsNullOrWhiteSpace(q)) return Results.Ok(Array.Empty<PlaceSuggestionDto>());

    var suggestions = await places.SearchAsync(q, ct);

    return Results.Ok(suggestions
        .Select(s => new PlaceSuggestionDto(s.GooglePlaceId, s.Name, s.Address))
        .ToList());
});

// ---------------------------------------------------------------------------
// Feedback
// ---------------------------------------------------------------------------

// Emails the submission straight to the developer's inbox - see FeedbackMailer. No
// feedback table or admin UI: not worth building for a low-traffic app.
registered.MapPost("/feedback", async (
    SubmitFeedbackRequest request, FeedbackMailer mailer, CurrentUser currentUser,
    ILogger<FeedbackMailer> logger, CancellationToken ct) =>
{
    var message = request.Message?.Trim();
    var errors = new Dictionary<string, string[]>();

    if (!FeedbackTypes.IsValid(request.Type))
    {
        errors["type"] = [$"Type must be one of: {string.Join(", ", FeedbackTypes.All)}."];
    }
    if (string.IsNullOrWhiteSpace(message))
    {
        errors["message"] = ["Say something before submitting."];
    }
    if (errors.Count > 0) return Results.ValidationProblem(errors);

    if (!mailer.IsConfigured)
    {
        return Results.Problem(
            title: "Feedback is not configured",
            detail: "Set Feedback:SmtpUser, Feedback:SmtpAppPassword and Feedback:RecipientEmail " +
                    "(or the matching Feedback__* environment variables) to enable the feedback form.",
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    var user = (await currentUser.GetAsync(ct))!;

    try
    {
        await mailer.SendAsync(request.Type!, message!, user.DisplayName, user.Handle, ct);
    }
    catch (Exception e)
    {
        // Logged here, not in FeedbackMailer itself - a send failure is otherwise
        // completely invisible server-side, surfaced to the caller only as a generic
        // 502 (no SMTP internals leaked to the client).
        logger.LogError(e, "Failed to send feedback email");
        return Results.Problem(
            title: "Could not send feedback",
            detail: "The email failed to send. Try again in a moment.",
            statusCode: StatusCodes.Status502BadGateway);
    }

    return Results.NoContent();
})
.RequireRateLimiting("feedback");

// ---------------------------------------------------------------------------
// Me
// ---------------------------------------------------------------------------

// The client's boot call. 200 with the caller's account - guests included, they're
// auto-provisioned by CurrentUser - or 404 if a real identity hasn't registered yet.
// Same registration-required problem type as RequireRegisteredFilter (just a 404 here
// instead of a 403 - "your own profile" 404s rather than forbids) so the client's
// single ApiException.needsRegistration check covers both.
api.MapGet("/me", async (CurrentUser currentUser, AppDbContext db, CancellationToken ct) =>
{
    var user = await currentUser.GetAsync(ct);
    if (user is null)
    {
        return Results.Problem(
            type: RequireRegisteredFilter.RegistrationRequiredType,
            title: "Registration required",
            detail: "This identity is authenticated but has not completed registration. POST /me first.",
            statusCode: StatusCodes.Status404NotFound);
    }

    var entryCount = await db.SpotEntries.CountAsync(e => e.UserId == user.Id, ct);

    return Results.Ok(new MeDto(user.Id, user.Handle, user.DisplayName, user.IsGuest, entryCount,
        user.AvatarId, user.AvatarColor, user.AvatarBackgroundTint));
});

// Completes registration. Works whether this identity is brand new, or a guest
// (IsGuest=true) upgrading in place - Firebase account linking keeps the same uid, so
// it's the same users row and the same auth_subject either way.
api.MapPost("/me", async (RegisterRequest request, CurrentUser currentUser, AppDbContext db, CancellationToken ct) =>
{
    var errors = ValidateHandle(request.Handle);

    var displayName = request.DisplayName?.Trim();
    if (string.IsNullOrWhiteSpace(displayName))
    {
        errors["displayName"] = ["A display name is required."];
    }

    if (errors.Count > 0) return Results.ValidationProblem(errors);

    var handle = request.Handle.Trim().ToLowerInvariant();
    var existing = await currentUser.GetAsync(ct);

    if (existing is not null && !existing.IsGuest)
    {
        return Results.Problem(
            title: "Already registered",
            detail: "This identity already has an account.",
            statusCode: StatusCodes.Status409Conflict);
    }

    var handleTaken = existing is null
        ? await db.Users.AnyAsync(u => u.Handle == handle, ct)
        : await db.Users.AnyAsync(u => u.Handle == handle && u.Id != existing.Id, ct);

    if (handleTaken)
    {
        return Results.Problem(
            title: "Handle already taken",
            statusCode: StatusCodes.Status409Conflict);
    }

    if (existing is null)
    {
        var created = new User
        {
            Id = Guid.CreateVersion7(),
            Handle = handle,
            DisplayName = displayName!,
            AuthProvider = currentUser.Provider,
            AuthSubject = currentUser.Subject,
            Email = currentUser.Email,
            IsGuest = false,
        };

        db.Users.Add(created);
        await db.SaveChangesAsync(ct);

        return Results.Created("/me", new MeDto(created.Id, created.Handle, created.DisplayName, false, 0,
            created.AvatarId, created.AvatarColor, created.AvatarBackgroundTint));
    }

    existing.Handle = handle;
    existing.DisplayName = displayName!;
    existing.IsGuest = false;
    if (currentUser.Email is not null) existing.Email = currentUser.Email;

    await db.SaveChangesAsync(ct);

    var entryCount = await db.SpotEntries.CountAsync(e => e.UserId == existing.Id, ct);

    return Results.Ok(new MeDto(existing.Id, existing.Handle, existing.DisplayName, false, entryCount,
        existing.AvatarId, existing.AvatarColor, existing.AvatarBackgroundTint));
});

// Sets the caller's preset profile icon, accent color, and background-tint flag - the
// only pieces of Me that are mutable outside registration. AvatarId null reverts to the
// display-name-initial fallback. A plain 400 (not ValidationProblem) since these are
// simple enum-like fields, not a form.
registered.MapPut("/me/avatar", async (
    UpdateAvatarRequest request, CurrentUser currentUser, AppDbContext db, CancellationToken ct) =>
{
    if (!AvatarIds.IsValid(request.AvatarId))
    {
        return Results.Problem(
            title: "Invalid avatar",
            detail: "avatarId must be one of the preset icons.",
            statusCode: StatusCodes.Status400BadRequest);
    }

    if (!AvatarColors.IsValid(request.AvatarColor))
    {
        return Results.Problem(
            title: "Invalid avatar color",
            detail: "avatarColor must be one of the preset accent colors, or omitted.",
            statusCode: StatusCodes.Status400BadRequest);
    }

    var user = await currentUser.GetAsync(ct);
    user!.AvatarId = request.AvatarId;
    user.AvatarColor = request.AvatarColor;
    user.AvatarBackgroundTint = request.AvatarBackgroundTint;
    await db.SaveChangesAsync(ct);

    var entryCount = await db.SpotEntries.CountAsync(e => e.UserId == user.Id, ct);

    return Results.Ok(new MeDto(user.Id, user.Handle, user.DisplayName, user.IsGuest, entryCount,
        user.AvatarId, user.AvatarColor, user.AvatarBackgroundTint));
});

// Permanently deletes the caller's account and every trace of their own data - Apple
// guideline 5.1.1(v) requires this wherever an app supports account creation. A hard
// delete, not a soft one via User.DeletedAt: nothing downstream reads that column today,
// and Apple's requirement is that the data is actually gone, not just hidden.
//
// SpotEntry/SpotVisit rows cascade at the DB level (see AppDbContext's OnDelete.Cascade
// for both), same as spot_entry_tags underneath SpotEntry. Spot itself and any Label the
// user requested/approved survive - both are shared/global rows (AddedBy/RequestedBy/
// ApprovedBy just go null, same SetNull behavior DELETE /spots/{id}/entry doesn't need
// to think about because it never touches those tables). What's left to do by hand is
// exactly what a cascade can't express: VisitCount is a cached counter, not derived by
// RecomputeAggregates, so it's decremented per spot before the visits disappear; and the
// EntryCount/Avg*/SpotTagCount aggregates on every spot the user rated need the same
// rebuild DELETE /spots/{id}/entry triggers, just for each of those spots instead of one.
registered.MapDelete("/me", async (AppDbContext db, CurrentUser currentUser, CancellationToken ct) =>
{
    var user = (await currentUser.GetAsync(ct))!;

    var ratedSpotIds = await db.SpotEntries
        .Where(e => e.UserId == user.Id)
        .Select(e => e.SpotId)
        .Distinct()
        .ToListAsync(ct);

    var visitCountsBySpot = await db.SpotVisits
        .Where(v => v.UserId == user.Id)
        .GroupBy(v => v.SpotId)
        .Select(g => new { SpotId = g.Key, Count = g.Count() })
        .ToListAsync(ct);

    foreach (var group in visitCountsBySpot)
    {
        var spot = await db.Spots.FirstOrDefaultAsync(s => s.Id == group.SpotId, ct);
        if (spot is not null) spot.VisitCount = Math.Max(0, spot.VisitCount - group.Count);
    }

    await db.SaveChangesAsync(ct);

    db.Users.Remove(user);
    await db.SaveChangesAsync(ct);

    foreach (var spotId in ratedSpotIds)
    {
        await RecomputeAggregates(db, spotId, ct);
    }

    return Results.NoContent();
});

// ---------------------------------------------------------------------------
// Labels
// ---------------------------------------------------------------------------

// The picker's data source: only the standardized, moderated vocabulary. Guests get
// this too (RequireRegisteredFilter passes them via auto-provisioning).
registered.MapGet("/labels", async (AppDbContext db, CancellationToken ct) =>
    await db.Labels
        .Where(l => l.Status == LabelStatuses.Approved)
        .OrderBy(l => l.Slug)
        .Select(l => new LabelDto(l.Id, l.Slug, l.DisplayName, l.Status, l.Polarity))
        .ToListAsync(ct));

// Requests a new label. Idempotent by slug, same shape as POST /spots: an existing
// approved or still-pending label is returned rather than duplicated. A previously
// rejected slug is a 409 rather than silently resurrecting it - no "reconsider"
// endpoint this pass, an admin re-opens it by hand-editing the row.
registered.MapPost("/labels", async (
    RequestLabelRequest request, CurrentUser currentUser, AppDbContext db, CancellationToken ct) =>
{
    var slug = Slugify(request.Name);
    var displayName = request.Name?.Trim();

    if (string.IsNullOrWhiteSpace(displayName) || slug.Length is < 2 or > 30 ||
        !Regex.IsMatch(slug, @"^[a-z0-9]+(-[a-z0-9]+)*$"))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["name"] = ["Give the tag a name with at least 2 letters or numbers in it."],
        });
    }

    var existing = await db.Labels.FirstOrDefaultAsync(l => l.Slug == slug, ct);

    if (existing is not null)
    {
        if (existing.Status == LabelStatuses.Rejected)
        {
            return Results.Problem(
                title: "That tag was already reviewed and rejected",
                statusCode: StatusCodes.Status409Conflict);
        }

        return Results.Ok(new LabelDto(existing.Id, existing.Slug, existing.DisplayName, existing.Status, existing.Polarity));
    }

    var requestedBy = await currentUser.IdAsync(ct);

    var created = new Label
    {
        Id = Guid.CreateVersion7(),
        Slug = slug,
        DisplayName = displayName,
        Status = LabelStatuses.Pending,
        RequestedBy = requestedBy,
    };

    db.Labels.Add(created);
    await db.SaveChangesAsync(ct);

    return Results.Created(
        $"/labels/{created.Id}",
        new LabelDto(created.Id, created.Slug, created.DisplayName, created.Status, created.Polarity));
});

// ---------------------------------------------------------------------------
// Admin — label moderation. No client UI: exercised via curl, either against a real
// account with is_admin hand-set, or locally against the dev-bypass identity (seeded
// as admin). See RequireAdminFilter.
// ---------------------------------------------------------------------------

var admin = registered.MapGroup("").AddEndpointFilter<RequireAdminFilter>();

admin.MapGet("/admin/labels/pending", async (AppDbContext db, CancellationToken ct) =>
    await db.Labels
        .Where(l => l.Status == LabelStatuses.Pending)
        .OrderBy(l => l.CreatedAt)
        .Select(l => new PendingLabelDto(l.Id, l.Slug, l.DisplayName, l.RequestedBy, l.CreatedAt))
        .ToListAsync(ct));

// The requester never picks positive/negative (see RequestLabelRequest) — approval is
// where that call gets made, so it's a required argument here rather than a default.
admin.MapPost("/admin/labels/{id:guid}/approve", async (
    Guid id, ApproveLabelRequest request, CurrentUser currentUser, AppDbContext db, CancellationToken ct) =>
{
    if (!LabelPolarities.IsValid(request.Polarity))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["polarity"] = ["Polarity must be 'positive' or 'negative'."],
        });
    }

    var label = await db.Labels.FirstOrDefaultAsync(l => l.Id == id, ct);
    if (label is null) return Results.NotFound();

    label.Status = LabelStatuses.Approved;
    label.Polarity = request.Polarity;
    label.ApprovedBy = await currentUser.IdAsync(ct);
    await db.SaveChangesAsync(ct);

    return Results.Ok(new LabelDto(label.Id, label.Slug, label.DisplayName, label.Status, label.Polarity));
});

admin.MapPost("/admin/labels/{id:guid}/reject", async (
    Guid id, CurrentUser currentUser, AppDbContext db, CancellationToken ct) =>
{
    var label = await db.Labels.FirstOrDefaultAsync(l => l.Id == id, ct);
    if (label is null) return Results.NotFound();

    label.Status = LabelStatuses.Rejected;
    label.ApprovedBy = await currentUser.IdAsync(ct);
    await db.SaveChangesAsync(ct);

    return Results.Ok(new LabelDto(label.Id, label.Slug, label.DisplayName, label.Status, label.Polarity));
});

// ---------------------------------------------------------------------------
// Spots
// ---------------------------------------------------------------------------

// Creates a spot, or returns the existing one if this place is already known.
// Idempotent by Place ID, which is what stops two users creating the same cafe twice.
registered.MapPost("/spots", async (
    CreateSpotRequest request,
    AppDbContext db,
    PlacesClient places,
    CurrentUser currentUser,
    CancellationToken ct) =>
{
    var userId = await currentUser.IdAsync(ct);
    Spot spot;

    if (!string.IsNullOrWhiteSpace(request.GooglePlaceId))
    {
        var existing = await db.Spots
            .FirstOrDefaultAsync(s => s.GooglePlaceId == request.GooglePlaceId, ct);

        if (existing is not null) return Results.Ok(await ToDetailDto(existing, db, places, userId, ct));

        var details = await places.GetDetailsAsync(request.GooglePlaceId, ct);

        if (details is null)
        {
            return Results.Problem(
                title: "Could not look up that place",
                detail: "Google Places did not return details for that Place ID. Check the " +
                        "API key, or add the spot manually.",
                statusCode: StatusCodes.Status502BadGateway);
        }

        spot = new Spot
        {
            Id = Guid.CreateVersion7(),
            GooglePlaceId = details.GooglePlaceId,
            Name = details.Name,
            FormattedAddress = details.FormattedAddress,
            Latitude = details.Latitude,
            Longitude = details.Longitude,
            PriceLevel = details.PriceLevel,
            WebsiteUrl = details.WebsiteUrl,
            Phone = details.Phone,
            UtcOffsetMinutes = details.UtcOffsetMinutes,
            PlacesSyncedAt = DateTime.UtcNow,
            AddedBy = userId,
        };
    }
    else
    {
        // Manual fallback: a campus study room or a library floor usually isn't in
        // Places at all. No coordinates, so it won't appear on the map until someone
        // links it to a real place.
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["name"] = ["A spot needs either a googlePlaceId or a name."],
            });
        }

        spot = new Spot
        {
            Id = Guid.CreateVersion7(),
            Name = request.Name.Trim(),
            FormattedAddress = string.IsNullOrWhiteSpace(request.Address) ? null : request.Address.Trim(),
            AddedBy = userId,
        };
    }

    db.Spots.Add(spot);
    await db.SaveChangesAsync(ct);

    return Results.Created($"/spots/{spot.Id}", await ToDetailDto(spot, db, places, userId, ct));
});

// Edits an existing spot's own Name/Address — the shared record, not any one entry.
// Used by the edit-spot flow to fix or add an address a manually-entered spot never
// had; Address may be cleared back to null, Name may not.
registered.MapPut("/spots/{id:guid}", async (
    Guid id,
    UpdateSpotRequest request,
    AppDbContext db,
    PlacesClient places,
    CurrentUser currentUser,
    CancellationToken ct) =>
{
    if (string.IsNullOrWhiteSpace(request.Name))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["name"] = ["A spot needs a name."],
        });
    }

    var spot = await db.Spots.FirstOrDefaultAsync(s => s.Id == id, ct);
    if (spot is null) return Results.NotFound();

    spot.Name = request.Name.Trim();
    spot.FormattedAddress = Trimmed(request.Address);

    await db.SaveChangesAsync(ct);

    var userId = await currentUser.IdAsync(ct);
    return Results.Ok(await ToDetailDto(spot, db, places, userId, ct));
});

// The ranked list behind the Spots tab: my entries, best first.
registered.MapGet("/me/spots", async (AppDbContext db, CurrentUser currentUser, CancellationToken ct) =>
{
    var userId = await currentUser.IdAsync(ct);

    return await db.SpotEntries
        .Where(e => e.UserId == userId)
        .Include(e => e.Spot)
        .OrderByDescending(e => e.Score)
        .ThenByDescending(e => e.UpdatedAt)
        .Select(e => new MySpotListItemDto(
            e.SpotId,
            e.Id,
            e.Spot!.Name,
            e.Spot.FormattedAddress,
            e.Score,
            new RatingsDto(e.Wifi, e.Noise, e.Outlets, e.Seating, e.TableSize, e.Coffee),
            e.GroupStudy,
            e.Tags.Select(t => t.Slug).ToList(),
            e.Spot.PriceLevel,
            e.CoffeeOrder,
            e.Notes,
            e.UpdatedAt))
        .ToListAsync(ct);
});

// Full detail for one spot, including hours fetched live from Places.
registered.MapGet("/spots/{id:guid}", async (
    Guid id, AppDbContext db, PlacesClient places, CurrentUser currentUser, CancellationToken ct) =>
{
    var spot = await db.Spots.FirstOrDefaultAsync(s => s.Id == id, ct);
    if (spot is null) return Results.NotFound();

    var userId = await currentUser.IdAsync(ct);

    return Results.Ok(await ToDetailDto(spot, db, places, userId, ct));
});

// ---------------------------------------------------------------------------
// My entry on a spot
// ---------------------------------------------------------------------------

// Upsert, not insert: re-rating a spot updates the row you already have (decision D2).
registered.MapPut("/spots/{id:guid}/entry", async (
    Guid id, UpsertEntryRequest request, AppDbContext db, CurrentUser currentUser, CancellationToken ct) =>
{
    var validationErrors = ValidateRatings(request.Ratings);
    if (validationErrors.Count > 0) return Results.ValidationProblem(validationErrors);

    if (!await db.Spots.AnyAsync(s => s.Id == id, ct)) return Results.NotFound();

    var tagSlugs = (request.TagSlugs ?? [])
        .Select(s => s.Trim().ToLowerInvariant())
        .Distinct()
        .ToList();

    var tags = tagSlugs.Count == 0
        ? []
        : await db.Labels
            .Where(l => tagSlugs.Contains(l.Slug) && l.Status == LabelStatuses.Approved)
            .ToListAsync(ct);

    if (tags.Count != tagSlugs.Count)
    {
        var invalid = tagSlugs.Except(tags.Select(t => t.Slug));
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["tagSlugs"] = [$"Unknown or unapproved tag(s): {string.Join(", ", invalid)}."],
        });
    }

    var visibility = Visibilities.IsValid(request.Visibility)
        ? request.Visibility!
        : Visibilities.Public;

    // RequireRegisteredFilter already ran, so this is never null.
    var user = (await currentUser.GetAsync(ct))!;

    var entry = await db.SpotEntries
        .Include(e => e.Tags)
        .FirstOrDefaultAsync(e => e.SpotId == id && e.UserId == user.Id, ct);

    var created = entry is null;

    if (created && user.IsGuest)
    {
        var guestEntryCount = await db.SpotEntries.CountAsync(e => e.UserId == user.Id, ct);
        if (guestEntryCount >= guestEntryLimit)
        {
            return Results.Problem(
                type: "https://studease.app/problems/entry-limit-reached",
                title: "Guest entry limit reached",
                detail: $"Guests can add up to {guestEntryLimit} spots. Create an account to add more.",
                statusCode: StatusCodes.Status403Forbidden);
        }
    }

    if (entry is null)
    {
        entry = new SpotEntry
        {
            Id = Guid.CreateVersion7(),
            UserId = user.Id,
            SpotId = id,
        };
        db.SpotEntries.Add(entry);
    }

    entry.Wifi = request.Ratings.Wifi;
    entry.Noise = request.Ratings.Noise;
    entry.Outlets = request.Ratings.Outlets;
    entry.Seating = request.Ratings.Seating;
    entry.TableSize = request.Ratings.TableSize;
    entry.Coffee = request.Ratings.Coffee;
    entry.GroupStudy = request.GroupStudy ?? false;
    entry.Tags = tags;
    entry.CoffeeOrder = Trimmed(request.CoffeeOrder);
    entry.Notes = Trimmed(request.Notes);
    entry.Visibility = visibility;

    await db.SaveChangesAsync(ct);
    await RecomputeAggregates(db, id, ct);

    var dto = ToEntryDto(entry);

    return created ? Results.Created($"/spots/{id}/entry", dto) : Results.Ok(dto);
});

// Removes my rating. The spot itself survives — someone else may have rated it.
registered.MapDelete("/spots/{id:guid}/entry", async (
    Guid id, AppDbContext db, CurrentUser currentUser, CancellationToken ct) =>
{
    var userId = await currentUser.IdAsync(ct);

    var entry = await db.SpotEntries
        .FirstOrDefaultAsync(e => e.SpotId == id && e.UserId == userId, ct);

    if (entry is null) return Results.NotFound();

    db.SpotEntries.Remove(entry);

    // My visits to this spot only make sense on top of a rating - POST
    // /spots/{id}/visits requires one to exist before it'll let you log one (see
    // "Requires an existing SpotEntry" above). Removing the rating without these
    // would leave them stranded: still visible in "my study history", but for a
    // spot I no longer have rated, and re-rating later would let you log a fresh
    // visit right on top of the old ones instead of starting clean.
    var myVisits = await db.SpotVisits
        .Where(v => v.SpotId == id && v.UserId == userId)
        .ToListAsync(ct);
    db.SpotVisits.RemoveRange(myVisits);

    if (myVisits.Count > 0)
    {
        var spot = await db.Spots.FirstOrDefaultAsync(s => s.Id == id, ct);
        if (spot is not null) spot.VisitCount = Math.Max(0, spot.VisitCount - myVisits.Count);
    }

    await db.SaveChangesAsync(ct);
    await RecomputeAggregates(db, id, ct);

    return Results.NoContent();
});

// ---------------------------------------------------------------------------
// Visits — "I'm studying here today" log entries. Separate from SpotEntry
// (decision D2, extended by D12): unlimited per (user, spot), never edited, no
// rating. Requires an existing SpotEntry for the same spot to create. Rows
// can be deleted (undoing a mislog) but never updated in place — see the
// DELETE route below, which is the one mutation D12's "append-only" allows.
// ---------------------------------------------------------------------------

const string RatingRequiredType = "https://studease.app/problems/rating-required";

// Requires an existing rating on this spot — enforced here, not just hidden in the UI.
registered.MapPost("/spots/{id:guid}/visits", async (
    Guid id, LogVisitRequest request, AppDbContext db, CurrentUser currentUser, CancellationToken ct) =>
{
    var spot = await db.Spots.FirstOrDefaultAsync(s => s.Id == id, ct);
    if (spot is null) return Results.NotFound();

    var user = (await currentUser.GetAsync(ct))!;

    var hasRated = await db.SpotEntries.AnyAsync(e => e.SpotId == id && e.UserId == user.Id, ct);
    if (!hasRated)
    {
        return Results.Problem(
            type: RatingRequiredType,
            title: "Rate this spot first",
            detail: $"Log a visit only after you've rated {spot.Name}.",
            statusCode: StatusCodes.Status403Forbidden);
    }

    var visit = new SpotVisit
    {
        Id = Guid.CreateVersion7(),
        UserId = user.Id,
        SpotId = id,
        Studied = Trimmed(request.Studied),
        DrinkOrder = Trimmed(request.DrinkOrder),
        VisitedAt = DateTime.UtcNow,
    };

    db.SpotVisits.Add(visit);
    spot.VisitCount++;
    await db.SaveChangesAsync(ct);

    return Results.Created($"/spots/{id}/visits", new VisitDto(
        visit.Id, id, spot.Name, visit.Studied, visit.DrinkOrder, visit.VisitedAt));
});

// This spot, mine only, newest first — backs the detail sheet's "Past visits" button.
registered.MapGet("/spots/{id:guid}/visits", async (
    Guid id, AppDbContext db, CurrentUser currentUser, CancellationToken ct) =>
{
    var spot = await db.Spots.FirstOrDefaultAsync(s => s.Id == id, ct);
    if (spot is null) return Results.NotFound();

    var userId = await currentUser.IdAsync(ct);

    return Results.Ok(await db.SpotVisits
        .Where(v => v.SpotId == id && v.UserId == userId)
        .OrderByDescending(v => v.VisitedAt)
        .Select(v => new VisitDto(v.Id, id, spot.Name, v.Studied, v.DrinkOrder, v.VisitedAt))
        .ToListAsync(ct));
});

// Undoes a mislogged visit. Doesn't touch SpotEntry (the rating) — only the log
// entry itself — and keeps VisitCount in sync since nothing else recomputes it.
registered.MapDelete("/spots/{id:guid}/visits/{visitId:guid}", async (
    Guid id, Guid visitId, AppDbContext db, CurrentUser currentUser, CancellationToken ct) =>
{
    var userId = await currentUser.IdAsync(ct);

    var visit = await db.SpotVisits
        .FirstOrDefaultAsync(v => v.Id == visitId && v.SpotId == id && v.UserId == userId, ct);

    if (visit is null) return Results.NotFound();

    db.SpotVisits.Remove(visit);

    var spot = await db.Spots.FirstOrDefaultAsync(s => s.Id == id, ct);
    if (spot is not null && spot.VisitCount > 0) spot.VisitCount--;

    await db.SaveChangesAsync(ct);

    return Results.NoContent();
});

// Every spot I've logged, newest first — backs the Profile tab's study history. Capped
// rather than cursor-paginated for v1, same tradeoff activity_events' fan-out-on-read
// makes: fine at this scale, revisit if the list grows.
registered.MapGet("/me/visits", async (AppDbContext db, CurrentUser currentUser, CancellationToken ct) =>
{
    var userId = await currentUser.IdAsync(ct);

    return Results.Ok(await db.SpotVisits
        .Where(v => v.UserId == userId)
        .Include(v => v.Spot)
        .OrderByDescending(v => v.VisitedAt)
        .Take(50)
        .Select(v => new VisitDto(v.Id, v.SpotId, v.Spot!.Name, v.Studied, v.DrinkOrder, v.VisitedAt))
        .ToListAsync(ct));
});

app.Run();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static string? Trimmed(string? value) =>
    string.IsNullOrWhiteSpace(value) ? null : value.Trim();

// Npgsql only understands the keyword=value ADO.NET format, but Neon (and most managed
// Postgres providers) hand out postgres:// URIs - translate when we see one.
static string? NormalizeConnectionString(string? value)
{
    if (string.IsNullOrEmpty(value)
        || !Uri.TryCreate(value, UriKind.Absolute, out var uri)
        || uri.Scheme is not ("postgres" or "postgresql"))
    {
        return value;
    }

    var userInfo = uri.UserInfo.Split(':', 2);

    return new NpgsqlConnectionStringBuilder
    {
        Host = uri.Host,
        Port = uri.Port == -1 ? 5432 : uri.Port,
        Database = uri.AbsolutePath.TrimStart('/'),
        Username = Uri.UnescapeDataString(userInfo[0]),
        Password = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : null,
        SslMode = SslMode.Require,
    }.ToString();
}

static Dictionary<string, string[]> ValidateRatings(RatingsDto? ratings)
{
    var errors = new Dictionary<string, string[]>();

    if (ratings is null)
    {
        errors["ratings"] = ["All six ratings are required."];
        return errors;
    }

    void Check(string name, short value)
    {
        if (value is < 1 or > 5)
        {
            errors[$"ratings.{name}"] = [$"{name} must be between 1 and 5."];
        }
    }

    Check("wifi", ratings.Wifi);
    Check("noise", ratings.Noise);
    Check("outlets", ratings.Outlets);
    Check("seating", ratings.Seating);
    Check("tableSize", ratings.TableSize);
    Check("coffee", ratings.Coffee);

    return errors;
}

static Dictionary<string, string[]> ValidateHandle(string? handle)
{
    var errors = new Dictionary<string, string[]>();
    var normalized = handle?.Trim().ToLowerInvariant() ?? "";

    if (!Regex.IsMatch(normalized, @"^[a-z0-9_]{3,30}$"))
    {
        errors["handle"] =
            ["Handle must be 3-30 characters: lowercase letters, numbers, and underscores only."];
    }
    else if (HandleRules.Reserved.Contains(normalized))
    {
        errors["handle"] = ["That handle is reserved."];
    }

    return errors;
}

// Lowercase kebab-case - "Best for reading" becomes "best-for-reading". Any run of
// non-alphanumeric characters (spaces, punctuation, an already-typed hyphen) collapses
// to a single "-"; leading/trailing hyphens are trimmed.
static string Slugify(string? name)
{
    var lowered = (name ?? "").ToLowerInvariant();
    return Regex.Replace(lowered, "[^a-z0-9]+", "-").Trim('-');
}

static SpotEntryDto ToEntryDto(SpotEntry entry) => new(
    entry.Id,
    entry.SpotId,
    new RatingsDto(
        entry.Wifi, entry.Noise, entry.Outlets, entry.Seating, entry.TableSize, entry.Coffee),
    entry.Score,
    entry.GroupStudy,
    entry.Tags.Select(t => t.Slug).ToList(),
    entry.CoffeeOrder,
    entry.Notes,
    entry.Visibility,
    entry.CreatedAt,
    entry.UpdatedAt);

static async Task<SpotDetailDto> ToDetailDto(
    Spot spot, AppDbContext db, PlacesClient places, Guid userId, CancellationToken ct)
{
    var myEntry = await db.SpotEntries
        .Include(e => e.Tags)
        .FirstOrDefaultAsync(e => e.SpotId == spot.Id && e.UserId == userId, ct);

    // The spot-wide aggregate — everyone's opinion, not just mine — parallel to
    // AvgScore/EntryCount below.
    var tagCounts = await db.SpotTagCounts
        .Where(x => x.SpotId == spot.Id)
        .Select(x => new SpotTagDto(x.Label!.Slug, x.EntryCount))
        .ToListAsync(ct);

    // Hours are never stored (decision D8), so this is where they come from.
    var hours = spot.GooglePlaceId is null
        ? null
        : (await places.GetDetailsAsync(spot.GooglePlaceId, ct))?.Hours;

    return new SpotDetailDto(
        spot.Id,
        spot.GooglePlaceId,
        spot.Name,
        spot.FormattedAddress,
        spot.Latitude,
        spot.Longitude,
        spot.PriceLevel,
        spot.WebsiteUrl,
        spot.Phone,
        hours?.OpenUntil,
        hours?.OpenNow,
        HoursUnavailable: hours is null,
        spot.EntryCount,
        spot.AvgScore,
        tagCounts,
        myEntry is null ? null : ToEntryDto(myEntry));
}

// The cached columns on spots are derived from spot_entries, so they're rebuilt from
// scratch after every write rather than nudged up and down.
static async Task RecomputeAggregates(AppDbContext db, Guid spotId, CancellationToken ct)
{
    var spot = await db.Spots.FirstOrDefaultAsync(s => s.Id == spotId, ct);
    if (spot is null) return;

    var visible = db.SpotEntries
        .Where(e => e.SpotId == spotId && e.Visibility != Visibilities.Private);

    if (!await visible.AnyAsync(ct))
    {
        spot.EntryCount = 0;
        spot.AvgScore = spot.AvgWifi = spot.AvgNoise = null;
        spot.AvgOutlets = spot.AvgSeating = spot.AvgTableSize = spot.AvgCoffee = null;
    }
    else
    {
        var stats = await visible
            .GroupBy(_ => 1)
            .Select(g => new
            {
                Count = g.Count(),
                Score = g.Average(e => e.Score),
                Wifi = g.Average(e => (decimal)e.Wifi),
                Noise = g.Average(e => (decimal)e.Noise),
                Outlets = g.Average(e => (decimal)e.Outlets),
                Seating = g.Average(e => (decimal)e.Seating),
                TableSize = g.Average(e => (decimal)e.TableSize),
                Coffee = g.Average(e => (decimal)e.Coffee),
            })
            .SingleAsync(ct);

        spot.EntryCount = stats.Count;
        spot.AvgScore = Math.Round(stats.Score, 1);
        spot.AvgWifi = Math.Round(stats.Wifi, 1);
        spot.AvgNoise = Math.Round(stats.Noise, 1);
        spot.AvgOutlets = Math.Round(stats.Outlets, 1);
        spot.AvgSeating = Math.Round(stats.Seating, 1);
        spot.AvgTableSize = Math.Round(stats.TableSize, 1);
        spot.AvgCoffee = Math.Round(stats.Coffee, 1);
    }

    await db.SaveChangesAsync(ct);

    // Tag counts: same delete-and-re-derive philosophy as the averages above, just as
    // rows instead of columns since tag cardinality is variable. Two separate
    // SaveChanges calls (delete flushed before insert) rather than folding into one -
    // a freshly re-added row would otherwise share a primary key with the row just
    // marked for deletion on the same (spot_id, label_id).
    var existingTagCounts = await db.SpotTagCounts.Where(x => x.SpotId == spotId).ToListAsync(ct);
    db.SpotTagCounts.RemoveRange(existingTagCounts);
    await db.SaveChangesAsync(ct);

    var tagCounts = await visible
        .SelectMany(e => e.Tags, (_, tag) => tag.Id)
        .GroupBy(labelId => labelId)
        .Select(g => new SpotTagCount { SpotId = spotId, LabelId = g.Key, EntryCount = g.Count() })
        .ToListAsync(ct);

    db.SpotTagCounts.AddRange(tagCounts);
    await db.SaveChangesAsync(ct);
}

// Reserved handles would collide with this API's own URL space (GET /users/{handle} vs
// GET /me), not just look silly. Mirrors context/auth-plan.md's handle rules.
static class HandleRules
{
    public static readonly string[] Reserved =
    [
        "me", "admin", "api", "spots", "places", "feed", "users", "photos",
        "support", "help", "settings", "about",
    ];
}

// Needed so WebApplicationFactory<Program> (or `dotnet ef`) can see this as a type.
public partial class Program;
