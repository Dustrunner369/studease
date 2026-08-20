using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace study_spot_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddLabelPolarity : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "polarity",
                table: "labels",
                type: "text",
                nullable: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_labels_polarity_valid",
                table: "labels",
                sql: "polarity IS NULL OR polarity IN ('positive', 'negative')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_labels_polarity_valid",
                table: "labels");

            migrationBuilder.DropColumn(
                name: "polarity",
                table: "labels");
        }
    }
}
