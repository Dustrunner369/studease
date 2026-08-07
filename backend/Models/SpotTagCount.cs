namespace study_spot_backend.Models;

// A cached rollup: how many of a spot's (non-private) entries carry a given label.
// Rebuilt from scratch inside RecomputeAggregates whenever an entry is written or
// deleted, same "delete and re-derive" style as Spot's avg_* columns — SpotEntry.Tags
// is the source of truth, this is derived data. Pure cache row, no independent
// lifecycle, so unlike Label/Spot/SpotEntry it doesn't implement ITimestamped.
//
// Doubles as the feature matrix a future recommender would want (spot x label
// weights) — not used for that yet, just a free byproduct of following the existing
// aggregate pattern.
public class SpotTagCount
{
    public Guid SpotId { get; set; }
    public Guid LabelId { get; set; }
    public int EntryCount { get; set; }

    public Spot? Spot { get; set; }
    public Label? Label { get; set; }
}
