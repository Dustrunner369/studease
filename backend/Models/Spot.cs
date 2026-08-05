namespace study_spot_backend.Models;

public static class SpotTypes
{
    public const string Cafe = "cafe";
    public const string Library = "library";
    public const string Campus = "campus";
    public const string Other = "other";

    public static readonly string[] All = [Cafe, Library, Campus, Other];

    public static bool IsValid(string? value) => value is not null && All.Contains(value);

    // Google's place types don't have a "study spot" notion, so we map the ones that
    // matter and let everything else fall through to café — the common case.
    public static string FromGoogleTypes(IEnumerable<string>? googleTypes)
    {
        var types = googleTypes?.ToHashSet() ?? [];

        if (types.Contains("library")) return Library;
        if (types.Contains("university") || types.Contains("school")) return Campus;
        if (types.Contains("cafe") || types.Contains("coffee_shop")) return Cafe;

        return Cafe;
    }
}

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

    public string Type { get; set; } = SpotTypes.Cafe;

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
    public decimal? AvgCoffee { get; set; }

    // NOTE: deliberately no opening-hours columns. Hours are fetched live from the
    // Places API when a spot is rendered (decision D8 in context/README.md).

    public List<SpotEntry> Entries { get; set; } = [];
}
