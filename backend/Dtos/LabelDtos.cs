namespace study_spot_backend.Dtos;

// The standardized tag vocabulary. See Models/Label.cs and context/api-contracts.md.

public record LabelDto(Guid Id, string Slug, string DisplayName, string Status);

public record RequestLabelRequest(string Name);

// A spot-level aggregate row from SpotTagCount — how many (non-private) entries on
// this spot carry the label. Distinct from the flat string[] slugs on SpotEntryDto/
// MySpotListItemDto, which are one entry's own tags.
public record SpotTagDto(string Slug, int Count);

public record PendingLabelDto(Guid Id, string Slug, string DisplayName, Guid? RequestedBy, DateTime CreatedAt);
