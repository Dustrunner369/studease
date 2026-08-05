namespace study_spot_backend.Models;

// Implemented by every entity that tracks when it was written, so AppDbContext can
// stamp them all in one place instead of each endpoint remembering to.
public interface ITimestamped
{
    DateTime CreatedAt { get; set; }
    DateTime UpdatedAt { get; set; }
}
