namespace study_spot_backend.Models;

public static class LabelStatuses
{
    public const string Pending = "pending";
    public const string Approved = "approved";
    public const string Rejected = "rejected";

    public static readonly string[] All = [Pending, Approved, Rejected];

    public static bool IsValid(string? value) => value is not null && All.Contains(value);
}

// A tag reads as either a compliment or a complaint — "Cozy" vs "Too loud". The
// requester never picks this; it's decided by whoever approves the request (see
// Program.cs POST /admin/labels/{id}/approve), which is what keeps a requester from
// sneaking a negative-sounding tag in as positive or vice versa.
public static class LabelPolarities
{
    public const string Positive = "positive";
    public const string Negative = "negative";

    public static readonly string[] All = [Positive, Negative];

    public static bool IsValid(string? value) => value is not null && All.Contains(value);
}

// One entry in the standardized, global tag vocabulary — replaces the old per-spot
// Type. Applied per SpotEntry (one user's opinion, see SpotEntry.Tags), never directly
// on Spot. A user requests a label by name; it starts Pending and is unusable until an
// admin approves it, which is what keeps the vocabulary standardized enough to filter
// and, eventually, recommend on.
public class Label : ITimestamped
{
    public Guid Id { get; set; }

    // Normalized: lowercase kebab-case — "Best for reading" becomes "best-for-reading".
    // The #slug pill in the picker/filter chips is plain text (Text('#${slug}')), not a
    // real hashtag parser, so a hyphen renders fine there (decision D14, 2026-08-31,
    // reversing the earlier no-hyphen rule). See ck_labels_slug_format in AppDbContext.
    public required string Slug { get; set; }

    // The human-readable form, as typed. Can't be losslessly reconstructed from Slug,
    // so it's stored separately — mainly seen in the moderation queue.
    public required string DisplayName { get; set; }

    public string Status { get; set; } = LabelStatuses.Pending;

    // Null until approved — a Pending or Rejected label was never assigned one.
    public string? Polarity { get; set; }

    public Guid? RequestedBy { get; set; }
    public Guid? ApprovedBy { get; set; } // set on reject too — "who reviewed this"

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public List<SpotEntry> Entries { get; set; } = [];
}
