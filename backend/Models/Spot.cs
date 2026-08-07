namespace study_spot_backend.Models;

// One row per real-world place, shared by every user. Facts about the place live
// here; what any one person thinks of it lives on SpotEntry.
public class Spot : ITimestamped
{
    public Guid Id { get; set; }

    // The dedupe key: two users adding the same café resolve to the same row.
    // Nullable because not every study spot exists in Google Places — a campus study
    // room usually doesn't — so manual entry is allowed. Unique where present.
    public string? GooglePlaceId { get; set; }

    // Snapshot of Places data, refreshed by PlacesSyncedAt. Stored so a list renders
    // without one API call per row.
    public required string Name { get; set; }
    public string? FormattedAddress { get; set; }

    // Null for manually entered spots — we don't geocode typed addresses.
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }

    public short? PriceLevel { get; set; }
    public string? WebsiteUrl { get; set; }
    public string? Phone { get; set; }

    // Offset from UTC at this place, used to work out its local "now" when deciding
    // whether it's open. Comes from Places; null for manual spots.
    public int? UtcOffsetMinutes { get; set; }
    public DateTime? PlacesSyncedAt { get; set; }

    public Guid? AddedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Cached aggregates over non-private entries, recomputed whenever an entry is
    // written. Derived data — SpotEntry is the source of truth.
    public int EntryCount { get; set; }
    public decimal? AvgScore { get; set; }
    public decimal? AvgWifi { get; set; }
    public decimal? AvgNoise { get; set; }
    public decimal? AvgOutlets { get; set; }
    public decimal? AvgSeating { get; set; }
    public decimal? AvgTableSize { get; set; }
    public decimal? AvgCoffee { get; set; }

    // NOTE: no group-study aggregate. GroupStudy stays one user's verdict on their own
    // entry; rolling it up into "8 of 12 say group-friendly" is a deliberate non-goal.

    // NOTE: deliberately no opening-hours columns. Hours are fetched live from the
    // Places API when a spot is rendered (decision D8 in context/README.md).

    // NOTE: no Type column (removed 2026-08-06) — replaced by the global label/tag
    // system. Tag aggregation for a spot lives in SpotTagCount, not an inline column
    // here, because tag cardinality is variable, unlike the six fixed rating categories
    // above.

    public List<SpotEntry> Entries { get; set; } = [];
}
