using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace study_spot_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddSpotVisits : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "visit_count",
                table: "spots",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "spot_visits",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    spot_id = table.Column<Guid>(type: "uuid", nullable: false),
                    studied = table.Column<string>(type: "text", nullable: true),
                    drink_order = table.Column<string>(type: "text", nullable: true),
                    visited_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_spot_visits", x => x.id);
                    table.ForeignKey(
                        name: "fk_spot_visits_spots_spot_id",
                        column: x => x.spot_id,
                        principalTable: "spots",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_spot_visits_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_spot_visits_spot_id_user_id_visited_at",
                table: "spot_visits",
                columns: new[] { "spot_id", "user_id", "visited_at" },
                descending: new[] { false, false, true });

            migrationBuilder.CreateIndex(
                name: "ix_spot_visits_user_id_visited_at",
                table: "spot_visits",
                columns: new[] { "user_id", "visited_at" },
                descending: new[] { false, true });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "spot_visits");

            migrationBuilder.DropColumn(
                name: "visit_count",
                table: "spots");
        }
    }
}
