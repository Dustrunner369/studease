using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace study_spot_backend.Migrations
{
    /// <inheritdoc />
    public partial class AllowHyphenatedLabelSlugs : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_labels_slug_format",
                table: "labels");

            migrationBuilder.AddCheckConstraint(
                name: "ck_labels_slug_format",
                table: "labels",
                sql: "slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(slug) BETWEEN 2 AND 30");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_labels_slug_format",
                table: "labels");

            migrationBuilder.AddCheckConstraint(
                name: "ck_labels_slug_format",
                table: "labels",
                sql: "slug ~ '^[a-z0-9]{2,30}$'");
        }
    }
}
