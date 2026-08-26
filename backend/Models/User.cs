namespace study_spot_backend.Models;

// The preset profile-icon set (assets/illustrations/pfpIcons in the client). Fixed and
// small on purpose - free-form upload is a separate, later feature (see User.AvatarId).
// Null is a valid value here too - it means "no preset icon", i.e. the client falls
// back to the display-name initial.
public static class AvatarIds
{
    public const string Cafe01 = "cafe_01";
    public const string Cafe02 = "cafe_02";
    public const string Cafe03 = "cafe_03";
    public const string Cafe04 = "cafe_04";
    public const string Cafe05 = "cafe_05";
    public const string Cafe06 = "cafe_06";
    public const string Cafe07 = "cafe_07";
    public const string Cafe08 = "cafe_08";
    public const string Cafe09 = "cafe_09";
    public const string Cafe10 = "cafe_10";

    public static readonly string[] All =
        [Cafe01, Cafe02, Cafe03, Cafe04, Cafe05, Cafe06, Cafe07, Cafe08, Cafe09, Cafe10];

    public static bool IsValid(string? value) => value is null || All.Contains(value);
}

// A curated accent-color set the avatar icon (and optionally its background) can be
// tinted with. Unlike AvatarIds, null is valid — a color is optional.
public static class AvatarColors
{
    public const string Terracotta = "terracotta";
    public const string Slate = "slate";
    public const string Sage = "sage";
    public const string Plum = "plum";
    public const string Cranberry = "cranberry";
    public const string Mustard = "mustard";
    public const string Forest = "forest";
    public const string Denim = "denim";

    public static readonly string[] All =
        [Terracotta, Slate, Sage, Plum, Cranberry, Mustard, Forest, Denim];

    public static bool IsValid(string? value) => value is null || All.Contains(value);
}

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

    // A preset icon slug (see AvatarIds), null until the user picks one. Distinct from
    // AvatarUrl: this is a fixed-set key, not a free-form link. Once uploads land, an
    // uploaded photo should populate AvatarUrl and this should be cleared - clients
    // prefer AvatarUrl over AvatarId when both are somehow set.
    public string? AvatarId { get; set; }

    // A slug from AvatarColors, null until the user picks one — the client renders its
    // own default ink color while this is null.
    public string? AvatarColor { get; set; }

    // Whether the avatar circle's background is also tinted by AvatarColor, vs. just
    // the icon. Meaningless while AvatarColor is null.
    public bool AvatarBackgroundTint { get; set; }

    public string? AvatarUrl { get; set; }
    public string? Bio { get; set; }
    public bool IsPrivate { get; set; }

    // True for a Firebase anonymous session auto-provisioned by CurrentUser so guests
    // never see a registration screen. Handle is a throwaway "guest_xxxxx" until POST
    // /me flips this to false - which happens in place, because Firebase account
    // linking keeps the same uid, so it's still the same row and the same auth_subject.
    public bool IsGuest { get; set; }

    // The schema's first permission field, deliberately minimal: one boolean gating
    // RequireAdminFilter on the label-moderation endpoints. Not a roles table - there's
    // no self-serve way to become admin, promotion is a manual `UPDATE users SET
    // is_admin = true`. The seeded dev user is admin so those endpoints are reachable
    // locally via the dev bypass.
    public bool IsAdmin { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }

    public List<SpotEntry> Entries { get; set; } = [];
}
