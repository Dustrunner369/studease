using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace study_spot_backend.Services;

// Dev only: authenticates every request as the seeded dev user, so curl and the Angular
// app keep working without a real Firebase token. Only registered when IsDevelopment()
// AND Auth:AllowDevBypass are both true (see Program.cs) - two conditions, not one, so an
// env var alone can never disable auth on a deployed instance.
public class DevBypassAuthHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = new[]
        {
            // Matches AppDbContext.DevUserId's seeded (auth_provider, auth_subject).
            new Claim(ClaimTypes.NameIdentifier, "local"),
            new Claim("auth_provider", "dev"),
        };

        var identity = new ClaimsIdentity(claims, Scheme.Name);
        var ticket = new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme.Name);

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
