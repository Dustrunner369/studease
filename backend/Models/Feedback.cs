namespace study_spot_backend.Models;

public static class FeedbackTypes
{
    public const string Bug = "bug";
    public const string FeatureRequest = "feature_request";
    public const string Other = "other";

    public static readonly string[] All = [Bug, FeatureRequest, Other];

    public static bool IsValid(string? value) => value is not null && All.Contains(value);
}
