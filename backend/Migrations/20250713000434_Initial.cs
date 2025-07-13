using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace study_spot_backend.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "StudySpots",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Name = table.Column<string>(type: "text", nullable: true),
                    Address = table.Column<string>(type: "text", nullable: true),
                    HasCharging = table.Column<bool>(type: "boolean", nullable: false),
                    Seating = table.Column<int>(type: "integer", nullable: false),
                    CoffeeQuality = table.Column<int>(type: "integer", nullable: false),
                    GeneralPrice = table.Column<string>(type: "text", nullable: true),
                    OpenUntil = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    DrinkOrder = table.Column<string>(type: "text", nullable: true),
                    ExtraNotes = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StudySpots", x => x.Id);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "StudySpots");
        }
    }
}
