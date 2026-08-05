using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace study_spot_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddTableSizeAndGroupStudy : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "avg_table_size",
                table: "spots",
                type: "numeric(2,1)",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "group_study",
                table: "spot_entries",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            // Hand-edited: EF scaffolded this with defaultValue 0, which the check
            // constraint below rejects — any entry written before this migration would
            // fail it and take the whole migration down with it. 3 is the neutral middle
            // of the 1-5 range: it marks these rows as "not actually answered" without
            // nudging their table-size average up or down.
            migrationBuilder.AddColumn<short>(
                name: "table_size",
                table: "spot_entries",
                type: "smallint",
                nullable: false,
                defaultValue: (short)3);

            migrationBuilder.AddCheckConstraint(
                name: "ck_spot_entries_table_size_range",
                table: "spot_entries",
                sql: "table_size BETWEEN 1 AND 5");

            // The two defaults above exist only to backfill rows that predate these
            // columns. The model declares no defaults, so leaving them on the columns
            // would drift the database away from the snapshot — and both fields are
            // always supplied by the API on write anyway.
            migrationBuilder.Sql("ALTER TABLE spot_entries ALTER COLUMN table_size DROP DEFAULT;");
            migrationBuilder.Sql("ALTER TABLE spot_entries ALTER COLUMN group_study DROP DEFAULT;");

            // Spot aggregates are only recomputed when an entry is written, so without
            // this every pre-existing spot would sit with a populated avg_seating and a
            // NULL avg_table_size until someone happened to re-save it. Seed it here to
            // match what RecomputeAggregates would produce.
            migrationBuilder.Sql("""
                UPDATE spots s
                SET    avg_table_size = agg.avg_table_size
                FROM  (SELECT spot_id, ROUND(AVG(table_size), 1) AS avg_table_size
                       FROM   spot_entries
                       WHERE  visibility <> 'private'
                       GROUP  BY spot_id) agg
                WHERE s.id = agg.spot_id;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_spot_entries_table_size_range",
                table: "spot_entries");

            migrationBuilder.DropColumn(
                name: "avg_table_size",
                table: "spots");

            migrationBuilder.DropColumn(
                name: "group_study",
                table: "spot_entries");

            migrationBuilder.DropColumn(
                name: "table_size",
                table: "spot_entries");
        }
    }
}
