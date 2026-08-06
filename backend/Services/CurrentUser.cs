using System.Security.Claims;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using study_spot_backend.Models;

namespace study_spot_backend.Services;

// Resolves the JWT's (provider, subject) to a users row, once per request.
//
// Guests (Firebase anonymous sign-in) are auto-provisioned here on first touch, so the
// app never shows a registration screen before someone has a reason to want one. A real,
// non-anonymous identity with no row is left as null - that's the "authenticated but
// unregistered" state RequireRegisteredFilter turns into a 403.
public class CurrentUser(IHttpContextAccessor accessor, AppDbContext db)
{
    private User? _cached;
    private bool _fetched;

    private ClaimsPrincipal Principal => accessor.HttpContext!.User;

    // "firebase" for real tokens; DevBypassAuthHandler stamps "dev" to match the seeded
    // dev row. Firebase tokens carry no such claim, so that's the default.
    public string Provider => Principal.FindFirstValue("auth_provider") ?? "firebase";

    // Firebase puts the uid in both `sub` and a `user_id` claim; JwtBearer maps `sub` to
    // ClaimTypes.NameIdentifier by default, hence the fallback.
    public string Subject =>
        Principal.FindFirstValue("user_id")
        ?? Principal.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? throw new InvalidOperationException("No subject claim on the authenticated principal.");

    public string? Email => Principal.FindFirstValue(ClaimTypes.Email);

    // Firebase stamps a `firebase` claim on every ID token with a nested
    // sign_in_provider; System.IdentityModel.Tokens.Jwt surfaces object-valued claims as
    // their raw JSON string rather than flattening them, hence the manual parse.
    public bool IsAnonymous
    {
        get
        {
            var raw = Principal.FindFirstValue("firebase");
            if (raw is null) return false;

            try
            {
                using var doc = JsonDocument.Parse(raw);
                return doc.RootElement.TryGetProperty("sign_in_provider", out var provider)
                    && provider.GetString() == "anonymous";
            }
            catch (JsonException)
            {
                return false;
            }
        }
    }

    /// The users row, or null when this identity hasn't registered yet.
    public async Task<User?> GetAsync(CancellationToken ct)
    {
        if (_fetched) return _cached;

        _cached = await Find(ct);

        if (_cached is null && IsAnonymous)
        {
            _cached = new User
            {
                Id = Guid.CreateVersion7(),
                // Throwaway on purpose: POST /me replaces it the moment this guest
                // registers for real. Only a-z0-9_ so it satisfies ck_users_handle_format.
                Handle = $"guest_{Guid.CreateVersion7():N}"[..14],
                DisplayName = "Guest",
                AuthProvider = Provider,
                AuthSubject = Subject,
                IsGuest = true,
            };

            db.Users.Add(_cached);

            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                // Lost a race with another request auto-provisioning the same identity.
                db.Entry(_cached).State = EntityState.Detached;
                _cached = await Find(ct);
            }
        }

        _fetched = true;
        return _cached;
    }

    /// For endpoints behind RequireRegisteredFilter, where GetAsync is guaranteed non-null.
    public async Task<Guid> IdAsync(CancellationToken ct) => (await GetAsync(ct))!.Id;

    private Task<User?> Find(CancellationToken ct) => db.Users.FirstOrDefaultAsync(
        u => u.AuthProvider == Provider && u.AuthSubject == Subject && u.DeletedAt == null, ct);
}
