using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace study_spot_backend.Migrations
{
    /// <inheritdoc />
    public partial class CleanupOrphanedVisits : Migration
    {
        // One-time data fix, not a schema change: DELETE /spots/{id}/entry didn't clean
        // up spot_visits before this session's fix to that endpoint, so any visit logged
        // against a spot whose rating was later deleted was left behind - still visible
        // in "my study history" for a spot the user no longer has rated. This removes
        // those pre-existing orphans and corrects each affected spot's visit_count to
        // match, the same way the fixed endpoint now does for future deletes.
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                WITH orphaned AS (
                    SELECT sv.id, sv.spot_id
                    FROM spot_visits sv
                    WHERE NOT EXISTS (
                        SELECT 1 FROM spot_entries se
                        WHERE se.user_id = sv.user_id AND se.spot_id = sv.spot_id
                    )
                ),
                deleted AS (
                    DELETE FROM spot_visits
                    WHERE id IN (SELECT id FROM orphaned)
                    RETURNING spot_id
                ),
                counts AS (
                    SELECT spot_id, COUNT(*) AS n FROM deleted GROUP BY spot_id
                )
                UPDATE spots
                SET visit_count = GREATEST(0, visit_count - counts.n)
                FROM counts
                WHERE spots.id = counts.spot_id;
                """);
        }

        // Not reversible: the deleted rows (and each spot's exact prior visit_count)
        // aren't preserved anywhere to restore from - same as any other one-time data
        // cleanup in this file's Migrations history.
        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
        }
    }
}
