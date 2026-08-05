namespace study_spot_backend.Dtos;

// Wire shapes. See context/api-contracts.md — these are the contract the Flutter and
// Angular clients are written against, so changing one is a breaking change.

// All six are 1-5 and all read "higher is better" — including Noise (5 = quiet) and
// TableSize (5 = big shared tables). TableSize is rated but excluded from Score; see
// SpotEntry.ComputeScore.
public record RatingsDto(
    short Wifi,
    short Noise,
    short Outlets,
    short Seating,
    short TableSize,
    short Coffee);

public record PlaceSuggestionDto(string GooglePlaceId, string Name, string Address);

// Either GooglePlaceId (the normal path) or Name (the manual fallback for places
// Google doesn't know about, like a campus study room).
public record CreateSpotRequest(
    string? GooglePlaceId,
    string? Name,
    string? Address,
    string? Type);

// GroupStudy is nullable on the way in only so an older client that omits it gets a
// default of false rather than a 400. Ratings stay required and complete.
public record UpsertEntryRequest(
    RatingsDto Ratings,
    bool? GroupStudy,
    string? CoffeeOrder,
    string? Notes,
    string? Visibility);

public record SpotEntryDto(
    Guid Id,
    Guid SpotId,
    RatingsDto Ratings,
    decimal Score,
    bool GroupStudy,
    string? CoffeeOrder,
    string? Notes,
    string Visibility,
    DateTime CreatedAt,
    DateTime UpdatedAt);

// One row of the ranked Spots tab: a spot flattened together with my entry, so the
// list renders without a second request per row.
public record MySpotListItemDto(
    Guid SpotId,
    Guid EntryId,
    string Name,
    string? Address,
    string Type,
    decimal Score,
    RatingsDto Ratings,
    bool GroupStudy,
    short? PriceLevel,
    string? CoffeeOrder,
    string? Notes,
    DateTime UpdatedAt);

// OpenUntil and IsOpenNow are not stored — they're fetched from Places while handling
// the request. HoursUnavailable distinguishes "Google has no hours" from "closed now".
public record SpotDetailDto(
    Guid Id,
    string? GooglePlaceId,
    string Name,
    string? Address,
    double? Latitude,
    double? Longitude,
    string Type,
    short? PriceLevel,
    string? WebsiteUrl,
    string? Phone,
    string? OpenUntil,
    bool? IsOpenNow,
    bool HoursUnavailable,
    int EntryCount,
    decimal? AvgScore,
    SpotEntryDto? MyEntry);
