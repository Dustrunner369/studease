using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace study_spot_backend.Services;

// Sends the feedback form straight to the developer's own inbox via Gmail SMTP with an
// App Password (myaccount.google.com/apppasswords, requires 2-Step Verification) rather
// than a third-party transactional-email service - this is a low-traffic app, so no
// feedback table/admin UI to build and no new service account to manage, just the Gmail
// account already checked daily.
public class FeedbackMailer(IConfiguration configuration, ILogger<FeedbackMailer> logger)
{
    private readonly string? _smtpUser = configuration["Feedback:SmtpUser"];
    private readonly string? _smtpAppPassword = configuration["Feedback:SmtpAppPassword"];
    private readonly string? _recipient = configuration["Feedback:RecipientEmail"];

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(_smtpUser) &&
        !string.IsNullOrWhiteSpace(_smtpAppPassword) &&
        !string.IsNullOrWhiteSpace(_recipient);

    public Task SendAsync(
        string type, string message, string displayName, string handle, CancellationToken ct = default)
    {
        var email = new MimeMessage();
        email.Subject = $"[Studease feedback] {type}";
        email.Body = new TextPart("plain") { Text = $"From: {displayName} (@{handle})\nType: {type}\n\n{message}" };
        return SendCoreAsync(email, ct);
    }

    // Same inbox, same delivery path as feedback — mirrors it rather than getting its own
    // service, since it's just as low-volume and the point is the same: one email lands
    // in the one Gmail account already checked daily. No tag-request table either.
    public Task SendTagRequestAsync(
        string tagName, string slug, string displayName, string handle, CancellationToken ct = default)
    {
        var email = new MimeMessage();
        email.Subject = $"[Studease tag request] {tagName}";
        email.Body = new TextPart("plain")
        {
            Text = $"From: {displayName} (@{handle})\n\nRequested tag: \"{tagName}\" (slug: {slug})",
        };
        return SendCoreAsync(email, ct);
    }

    private async Task SendCoreAsync(MimeMessage email, CancellationToken ct)
    {
        if (!IsConfigured) throw new InvalidOperationException("FeedbackMailer is not configured");

        email.From.Add(MailboxAddress.Parse(_smtpUser!));
        email.To.Add(MailboxAddress.Parse(_recipient!));

        using var client = new SmtpClient();
        try
        {
            // Some networks (this held true even locally over plain home wifi while
            // testing) can't complete the OCSP/CRL revocation check .NET attempts
            // during the handshake, which otherwise fails the connection outright even
            // though the certificate itself is valid - MailKit's documented fix is to
            // stop requiring that check specifically. Chain, hostname, and expiry are
            // still fully validated; only the revocation check is skipped.
            client.CheckCertificateRevocation = false;
            await client.ConnectAsync("smtp.gmail.com", 587, SecureSocketOptions.StartTls, ct);
            await client.AuthenticateAsync(_smtpUser!, _smtpAppPassword!, ct);
            await client.SendAsync(email, ct);
        }
        finally
        {
            // Best-effort: a failed disconnect shouldn't mask a real send failure, or
            // (on the success path) turn a delivered email into a 502 for the caller.
            try
            {
                await client.DisconnectAsync(true, ct);
            }
            catch (Exception e)
            {
                logger.LogWarning(e, "SMTP disconnect failed after sending feedback email");
            }
        }
    }
}
