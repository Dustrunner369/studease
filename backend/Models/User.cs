namespace study_spot_backend.Models;

// A person. Identity comes from an external provider — no passwords are stored here.
// See context/data-model.md for why (auth_provider, auth_subject) is the login key.
public class User : ITimestamped
{
    public Guid Id { get; set; }

    // Stored lowercase so the unique index is effectively case-insensitive:
    // @Matt and @matt are the same person.
    public required string Handle { get; set; }
    public required string DisplayName { get; set; }
    public string? Email { get; set; }

    // The IdP's name and its permanent id for this user (the OIDC `sub` claim).
    public required string AuthProvider { get; set; }
    public required string AuthSubject { get; set; }

    public string? AvatarUrl { get; set; }
    public string? Bio { get; set; }
    public bool IsPrivate { get; set; }

    // True for a Firebase anonymous session auto-provisioned by CurrentUser so guests
    // never see a registration screen. Handle is a throwaway "guest_xxxxx" until POST
    // /me flips this to false - which happens in place, because Firebase account
    // linking keeps the same uid, so it's still the same row and the same auth_subject.
    public bool IsGuest { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }

    public List<SpotEntry> Entries { get; set; } = [];
}
