using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace study_spot_backend.Services;

public record PlaceSuggestion(string GooglePlaceId, string Name, string Address);

public record OpeningHours(bool? OpenNow, string? OpenUntil);

public record PlaceDetails(
    string GooglePlaceId,
    string Name,
    string? FormattedAddress,
    double? Latitude,
    double? Longitude,
    short? PriceLevel,
    string? WebsiteUrl,
    string? Phone,
    int? UtcOffsetMinutes,
    IReadOnlyList<string> Types,
    OpeningHours? Hours);

// Thin wrapper over the Places API (New). Two calls are used: autocomplete to find a
// place while adding a spot, and details to fill in the facts we store plus the hours
// we deliberately don't (decision D8 in context/README.md).
//
// Everything degrades to null/empty rather than throwing when the API key is missing or
// Google is unhappy, so a spot with no hours still renders.
public class PlacesClient(HttpClient http, IConfiguration configuration, ILogger<PlacesClient> logger)
{
    private const string AutocompleteUrl = "https://places.googleapis.com/v1/places:autocomplete";
    private const string DetailsUrlFormat = "https://places.googleapis.com/v1/places/{0}";

    private const string DetailsFieldMask =
        "id,displayName,formattedAddress,location,types,priceLevel,websiteUri," +
        "nationalPhoneNumber,utcOffsetMinutes,regularOpeningHours,currentOpeningHours";

    private readonly string? _apiKey = configuration["Places:ApiKey"];

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_apiKey);

    public async Task<IReadOnlyList<PlaceSuggestion>> SearchAsync(
        string query, CancellationToken ct = default)
    {
        if (!IsConfigured || string.IsNullOrWhiteSpace(query)) return [];

        var body = JsonSerializer.Serialize(new { input = query });

        using var request = new HttpRequestMessage(HttpMethod.Post, AutocompleteUrl)
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json"),
        };
        request.Headers.Add("X-Goog-Api-Key", _apiKey);
        request.Headers.Add("X-Goog-FieldMask",
            "suggestions.placePrediction.placeId,suggestions.placePrediction.structuredFormat");

        using var document = await SendAsync(request, ct);
        if (document is null) return [];

        var suggestions = document.RootElement.GetChild("suggestions");
        if (suggestions.ValueKind != JsonValueKind.Array) return [];

        var results = new List<PlaceSuggestion>();

        foreach (var suggestion in suggestions.EnumerateArray())
        {
            var prediction = suggestion.GetChild("placePrediction");

            var placeId = prediction.GetStringOrNull("placeId");
            if (placeId is null) continue;

            var format = prediction.GetChild("structuredFormat");
            var name = format.GetChild("mainText").GetStringOrNull("text");
            var address = format.GetChild("secondaryText").GetStringOrNull("text");

            results.Add(new PlaceSuggestion(placeId, name ?? "Unnamed place", address ?? ""));
        }

        return results;
    }

    public async Task<PlaceDetails?> GetDetailsAsync(string placeId, CancellationToken ct = default)
    {
        if (!IsConfigured || string.IsNullOrWhiteSpace(placeId)) return null;

        var url = string.Format(DetailsUrlFormat, Uri.EscapeDataString(placeId));

        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        request.Headers.Add("X-Goog-Api-Key", _apiKey);
        request.Headers.Add("X-Goog-FieldMask", DetailsFieldMask);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        using var document = await SendAsync(request, ct);
        if (document is null) return null;

        var root = document.RootElement;
        var location = root.GetChild("location");
        var utcOffsetMinutes = root.GetInt32OrNull("utcOffsetMinutes");

        var typesElement = root.GetChild("types");
        var types = typesElement.ValueKind == JsonValueKind.Array
            ? typesElement.EnumerateArray().Select(t => t.GetString() ?? "").ToList()
            : [];

        return new PlaceDetails(
            GooglePlaceId: root.GetStringOrNull("id") ?? placeId,
            Name: root.GetChild("displayName").GetStringOrNull("text") ?? "Unnamed place",
            FormattedAddress: root.GetStringOrNull("formattedAddress"),
            Latitude: location.GetDoubleOrNull("latitude"),
            Longitude: location.GetDoubleOrNull("longitude"),
            PriceLevel: ParsePriceLevel(root.GetStringOrNull("priceLevel")),
            WebsiteUrl: root.GetStringOrNull("websiteUri"),
            Phone: root.GetStringOrNull("nationalPhoneNumber"),
            UtcOffsetMinutes: utcOffsetMinutes,
            Types: types,
            Hours: ParseHours(root, utcOffsetMinutes));
    }

    private async Task<JsonDocument?> SendAsync(HttpRequestMessage request, CancellationToken ct)
    {
        try
        {
            using var response = await http.SendAsync(request, ct);
            var payload = await response.Content.ReadAsStringAsync(ct);

            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("Places API returned {Status}: {Body}",
                    (int)response.StatusCode, payload);
                return null;
            }

            return JsonDocument.Parse(payload);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            logger.LogWarning(ex, "Places API call failed");
            return null;
        }
    }

    // "PRICE_LEVEL_MODERATE" -> 2. The suffix is matched rather than the whole string so
    // this keeps working if Google ever drops the prefix.
    private static short? ParsePriceLevel(string? value) => value switch
    {
        null => null,
        var v when v.EndsWith("FREE") => 0,
        var v when v.EndsWith("INEXPENSIVE") => 1,
        var v when v.EndsWith("MODERATE") => 2,
        var v when v.EndsWith("VERY_EXPENSIVE") => 4,
        var v when v.EndsWith("EXPENSIVE") => 3,
        _ => null,
    };

    // currentOpeningHours accounts for holidays, so prefer it and fall back to the
    // regular weekly schedule.
    private static OpeningHours? ParseHours(JsonElement root, int? utcOffsetMinutes)
    {
        var hours = root.GetChild("currentOpeningHours");
        if (hours.ValueKind != JsonValueKind.Object) hours = root.GetChild("regularOpeningHours");
        if (hours.ValueKind != JsonValueKind.Object) return null;

        return new OpeningHours(hours.GetBoolOrNull("openNow"), FindCloseTime(hours, utcOffsetMinutes));
    }

    // Google gives opening hours as periods with a day (0 = Sunday) and a wall-clock
    // time. Find the period covering the spot's local "now" and return when it closes.
    private static string? FindCloseTime(JsonElement hours, int? utcOffsetMinutes)
    {
        var periods = hours.GetChild("periods");
        if (periods.ValueKind != JsonValueKind.Array) return null;

        const int week = 7 * 24 * 60;

        var local = DateTime.UtcNow.AddMinutes(utcOffsetMinutes ?? 0);
        var nowMinutes = (int)local.DayOfWeek * 24 * 60 + local.Hour * 60 + local.Minute;

        foreach (var period in periods.EnumerateArray())
        {
            var open = period.GetChild("open");
            var close = period.GetChild("close");

            // A period with no close is Google's way of saying "open 24 hours".
            if (open.ValueKind != JsonValueKind.Object || close.ValueKind != JsonValueKind.Object)
            {
                continue;
            }

            var openAt = ToWeekMinutes(open);
            var closeAt = ToWeekMinutes(close);
            if (openAt is null || closeAt is null) continue;

            // Closing "before" opening means the period runs past midnight.
            var end = closeAt.Value <= openAt.Value ? closeAt.Value + week : closeAt.Value;

            var covers = (nowMinutes >= openAt.Value && nowMinutes < end)
                || (nowMinutes + week >= openAt.Value && nowMinutes + week < end);

            if (covers)
            {
                var hour = close.GetInt32OrNull("hour") ?? 0;
                var minute = close.GetInt32OrNull("minute") ?? 0;
                return $"{hour:D2}:{minute:D2}";
            }
        }

        return null;
    }

    private static int? ToWeekMinutes(JsonElement point)
    {
        var day = point.GetInt32OrNull("day");
        if (day is null) return null;

        var hour = point.GetInt32OrNull("hour") ?? 0;
        var minute = point.GetInt32OrNull("minute") ?? 0;

        return day.Value * 24 * 60 + hour * 60 + minute;
    }
}

// Reading Places responses means walking objects that may or may not be there. These
// return a harmless `default` (ValueKind == Undefined) instead of throwing, so lookups
// chain without a TryGetProperty ladder at every level.
internal static class JsonElementExtensions
{
    public static JsonElement GetChild(this JsonElement element, string name) =>
        element.ValueKind == JsonValueKind.Object && element.TryGetProperty(name, out var value)
            ? value
            : default;

    public static string? GetStringOrNull(this JsonElement element, string name) =>
        element.GetChild(name) is { ValueKind: JsonValueKind.String } value
            ? value.GetString()
            : null;

    public static bool? GetBoolOrNull(this JsonElement element, string name) =>
        element.GetChild(name) is { ValueKind: JsonValueKind.True or JsonValueKind.False } value
            ? value.GetBoolean()
            : null;

    public static double? GetDoubleOrNull(this JsonElement element, string name) =>
        element.GetChild(name) is { ValueKind: JsonValueKind.Number } value
            && value.TryGetDouble(out var result)
                ? result
                : null;

    public static int? GetInt32OrNull(this JsonElement element, string name) =>
        element.GetChild(name) is { ValueKind: JsonValueKind.Number } value
            && value.TryGetInt32(out var result)
                ? result
                : null;
}
