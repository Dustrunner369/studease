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

    // Six required ratings, 1-5, all "higher is better".
    public short Wifi { get; set; }
    public short Noise { get; set; } // 5 = quiet. Inverted on purpose, see data-model.md.
    public short Outlets { get; set; }
    public short Seating { get; set; }
    public short TableSize { get; set; } // 5 = big shared tables, room to spread out.
    public short Coffee { get; set; }

    // Whether this place worked for studying with other people. One user's verdict,
    // not a fact about the place — someone else may disagree on the same spot.
    public bool GroupStudy { get; set; }

    // Computed by Postgres as a stored generated column, so the three clients can't
    // disagree about what a spot scores. Read-only here by design.
    //
    // TableSize is rated but deliberately NOT scored: the 0.4 multiplier is calibrated
    // so five 1-5 ratings top out at exactly 10.0, and folding in a sixth would rebase
    // every score that already exists. GroupStudy is a bool and was never scoreable.
    public decimal Score { get; private set; }

    public string? CoffeeOrder { get; set; }
    public string? Notes { get; set; }

    public string Visibility { get; set; } = Visibilities.Public;

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public User? User { get; set; }
    public Spot? Spot { get; set; }

    // Mirrors the generated column, for callers that need the score before the round
    // trip (the aggregate recompute, mainly). Must stay in step with the
    // HasComputedColumnSql expression in AppDbContext — TableSize is excluded from both.
    public decimal ComputeScore() =>
        Math.Round((Wifi + Noise + Outlets + Seating + Coffee) * 0.4m, 1);
}
