using study_spot_backend;
using study_spot_backend.Dtos;
using study_spot_backend.Models;
using study_spot_backend.Services;
using Microsoft.EntityFrameworkCore;

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

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseNpgsql(connectionString).UseSnakeCaseNamingConvention());
builder.Services.AddDatabaseDeveloperPageExceptionFilter();
builder.Services.AddHttpClient<PlacesClient>();
builder.Services.AddProblemDetails();

var app = builder.Build();

// Automatically applies any database migrations at runtime.
// NOTE: fine while this is a one-person project, but this means a container restart
// runs whatever migration shipped in the image — including a destructive one. Make it
// a deliberate step before anyone else's data is in here.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.Migrate();
}

app.UseCors();

// No auth yet: every request acts as the seeded dev user.
var currentUserId = AppDbContext.DevUserId;

// ---------------------------------------------------------------------------
// Places
// ---------------------------------------------------------------------------

// Proxies Places Autocomplete so the API key never ships inside a client.
app.MapGet("/places/search", async (string? q, PlacesClient places, CancellationToken ct) =>
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
// Spots
// ---------------------------------------------------------------------------

// Creates a spot, or returns the existing one if this place is already known.
// Idempotent by Place ID, which is what stops two users creating the same cafe twice.
app.MapPost("/spots", async (
    CreateSpotRequest request,
    AppDbContext db,
    PlacesClient places,
    CancellationToken ct) =>
{
    Spot spot;

    if (!string.IsNullOrWhiteSpace(request.GooglePlaceId))
    {
        var existing = await db.Spots
            .FirstOrDefaultAsync(s => s.GooglePlaceId == request.GooglePlaceId, ct);

        if (existing is not null) return Results.Ok(await ToDetailDto(existing, db, places, currentUserId, ct));

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
            Type = SpotTypes.IsValid(request.Type)
                ? request.Type!
                : SpotTypes.FromGoogleTypes(details.Types),
            AddedBy = currentUserId,
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
            Type = SpotTypes.IsValid(request.Type) ? request.Type! : SpotTypes.Cafe,
            AddedBy = currentUserId,
        };
    }

    db.Spots.Add(spot);
    await db.SaveChangesAsync(ct);

    return Results.Created($"/spots/{spot.Id}", await ToDetailDto(spot, db, places, currentUserId, ct));
});

// The ranked list behind the Spots tab: my entries, best first.
app.MapGet("/me/spots", async (AppDbContext db, CancellationToken ct) =>
    await db.SpotEntries
        .Where(e => e.UserId == currentUserId)
        .Include(e => e.Spot)
        .OrderByDescending(e => e.Score)
        .ThenByDescending(e => e.UpdatedAt)
        .Select(e => new MySpotListItemDto(
            e.SpotId,
            e.Id,
            e.Spot!.Name,
            e.Spot.FormattedAddress,
            e.Spot.Type,
            e.Score,
            new RatingsDto(e.Wifi, e.Noise, e.Outlets, e.Seating, e.Coffee),
            e.Spot.PriceLevel,
            e.CoffeeOrder,
            e.Notes,
            e.UpdatedAt))
        .ToListAsync(ct));

// Full detail for one spot, including hours fetched live from Places.
app.MapGet("/spots/{id:guid}", async (
    Guid id, AppDbContext db, PlacesClient places, CancellationToken ct) =>
{
    var spot = await db.Spots.FirstOrDefaultAsync(s => s.Id == id, ct);

    return spot is null
        ? Results.NotFound()
        : Results.Ok(await ToDetailDto(spot, db, places, currentUserId, ct));
});

// ---------------------------------------------------------------------------
// My entry on a spot
// ---------------------------------------------------------------------------

// Upsert, not insert: re-rating a spot updates the row you already have (decision D2).
app.MapPut("/spots/{id:guid}/entry", async (
    Guid id, UpsertEntryRequest request, AppDbContext db, CancellationToken ct) =>
{
    var validationErrors = ValidateRatings(request.Ratings);
    if (validationErrors.Count > 0) return Results.ValidationProblem(validationErrors);

    if (!await db.Spots.AnyAsync(s => s.Id == id, ct)) return Results.NotFound();

    var visibility = Visibilities.IsValid(request.Visibility)
        ? request.Visibility!
        : Visibilities.Public;

    var entry = await db.SpotEntries
        .FirstOrDefaultAsync(e => e.SpotId == id && e.UserId == currentUserId, ct);

    var created = entry is null;

    if (entry is null)
    {
        entry = new SpotEntry
        {
            Id = Guid.CreateVersion7(),
            UserId = currentUserId,
            SpotId = id,
        };
        db.SpotEntries.Add(entry);
    }

    entry.Wifi = request.Ratings.Wifi;
    entry.Noise = request.Ratings.Noise;
    entry.Outlets = request.Ratings.Outlets;
    entry.Seating = request.Ratings.Seating;
    entry.Coffee = request.Ratings.Coffee;
    entry.CoffeeOrder = Trimmed(request.CoffeeOrder);
    entry.Notes = Trimmed(request.Notes);
    entry.Visibility = visibility;

    await db.SaveChangesAsync(ct);
    await RecomputeAggregates(db, id, ct);

    var dto = ToEntryDto(entry);

    return created ? Results.Created($"/spots/{id}/entry", dto) : Results.Ok(dto);
});

// Removes my rating. The spot itself survives — someone else may have rated it.
app.MapDelete("/spots/{id:guid}/entry", async (Guid id, AppDbContext db, CancellationToken ct) =>
{
    var entry = await db.SpotEntries
        .FirstOrDefaultAsync(e => e.SpotId == id && e.UserId == currentUserId, ct);

    if (entry is null) return Results.NotFound();

    db.SpotEntries.Remove(entry);
    await db.SaveChangesAsync(ct);
    await RecomputeAggregates(db, id, ct);

    return Results.NoContent();
});

app.Run();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static string? Trimmed(string? value) =>
    string.IsNullOrWhiteSpace(value) ? null : value.Trim();

static Dictionary<string, string[]> ValidateRatings(RatingsDto? ratings)
{
    var errors = new Dictionary<string, string[]>();

    if (ratings is null)
    {
        errors["ratings"] = ["All five ratings are required."];
        return errors;
    }

    void Check(string name, short value)
    {
        if (value is < 1 or > 5) errors[$"ratings.{name}"] = [$"{name} must be between 1 and 5."];
    }

    Check("wifi", ratings.Wifi);
    Check("noise", ratings.Noise);
    Check("outlets", ratings.Outlets);
    Check("seating", ratings.Seating);
    Check("coffee", ratings.Coffee);

    return errors;
}

static SpotEntryDto ToEntryDto(SpotEntry entry) => new(
    entry.Id,
    entry.SpotId,
    new RatingsDto(entry.Wifi, entry.Noise, entry.Outlets, entry.Seating, entry.Coffee),
    entry.Score,
    entry.CoffeeOrder,
    entry.Notes,
    entry.Visibility,
    entry.CreatedAt,
    entry.UpdatedAt);

static async Task<SpotDetailDto> ToDetailDto(
    Spot spot, AppDbContext db, PlacesClient places, Guid userId, CancellationToken ct)
{
    var myEntry = await db.SpotEntries
        .FirstOrDefaultAsync(e => e.SpotId == spot.Id && e.UserId == userId, ct);

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
        spot.Type,
        spot.PriceLevel,
        spot.WebsiteUrl,
        spot.Phone,
        hours?.OpenUntil,
        hours?.OpenNow,
        HoursUnavailable: hours is null,
        spot.EntryCount,
        spot.AvgScore,
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
        spot.AvgOutlets = spot.AvgSeating = spot.AvgCoffee = null;
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
                Coffee = g.Average(e => (decimal)e.Coffee),
            })
            .SingleAsync(ct);

        spot.EntryCount = stats.Count;
        spot.AvgScore = Math.Round(stats.Score, 1);
        spot.AvgWifi = Math.Round(stats.Wifi, 1);
        spot.AvgNoise = Math.Round(stats.Noise, 1);
        spot.AvgOutlets = Math.Round(stats.Outlets, 1);
        spot.AvgSeating = Math.Round(stats.Seating, 1);
        spot.AvgCoffee = Math.Round(stats.Coffee, 1);
    }

    await db.SaveChangesAsync(ct);
}
