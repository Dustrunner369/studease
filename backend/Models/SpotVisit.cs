namespace study_spot_backend.Models;

// One "I'm studying here today" log entry — separate from SpotEntry (decision D2,
// extended by D12): unlimited per (user, spot), immutable once created, carries no
// rating. Requires an existing SpotEntry for the same (user, spot) to create — enforced
// in Program.cs, not a DB constraint (a cross-table CHECK isn't expressible).
public class SpotVisit
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid SpotId { get; set; }

    public string? Studied { get; set; }
    public string? DrinkOrder { get; set; }

    // Stamped server-side at creation, never client-supplied — logging is always
    // "today", not backdated.
    public DateTime VisitedAt { get; set; }

    public User? User { get; set; }
    public Spot? Spot { get; set; }
}
