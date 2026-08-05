namespace study_spot_backend.Models;

public static class Visibilities
{
    public const string Public = "public";
    public const string Followers = "followers";
    public const string Private = "private";

    public static readonly string[] All = [Public, Followers, Private];

    public static bool IsValid(string? value) => value is not null && All.Contains(value);
}

// One user's opinion of one spot. Exactly one row per (user, spot) — re-rating a
// place is an update, not an insert.
public class SpotEntry : ITimestamped
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid SpotId { get; set; }

    // Five required ratings, 1-5, all "higher is better".
    public short Wifi { get; set; }
    public short Noise { get; set; } // 5 = quiet. Inverted on purpose, see data-model.md.
    public short Outlets { get; set; }
    public short Seating { get; set; }
    public short Coffee { get; set; }

    // Computed by Postgres as a stored generated column, so the three clients can't
    // disagree about what a spot scores. Read-only here by design.
    public decimal Score { get; private set; }

    public string? CoffeeOrder { get; set; }
    public string? Notes { get; set; }

    public string Visibility { get; set; } = Visibilities.Public;

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public User? User { get; set; }
    public Spot? Spot { get; set; }

    // Mirrors the generated column, for callers that need the score before the round
    // trip (the aggregate recompute, mainly).
    public decimal ComputeScore() =>
        Math.Round((Wifi + Noise + Outlets + Seating + Coffee) * 0.4m, 1);
}
