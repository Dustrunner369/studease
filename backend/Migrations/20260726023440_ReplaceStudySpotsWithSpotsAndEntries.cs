using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace study_spot_backend.Migrations
{
    /// <inheritdoc />
    public partial class ReplaceStudySpotsWithSpotsAndEntries : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "StudySpots");

            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    handle = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    display_name = table.Column<string>(type: "text", nullable: false),
                    email = table.Column<string>(type: "text", nullable: true),
                    auth_provider = table.Column<string>(type: "text", nullable: false),
                    auth_subject = table.Column<string>(type: "text", nullable: false),
                    avatar_url = table.Column<string>(type: "text", nullable: true),
                    bio = table.Column<string>(type: "text", nullable: true),
                    is_private = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    deleted_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_users", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "spots",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    google_place_id = table.Column<string>(type: "text", nullable: true),
                    name = table.Column<string>(type: "text", nullable: false),
                    formatted_address = table.Column<string>(type: "text", nullable: true),
                    latitude = table.Column<double>(type: "double precision", nullable: true),
                    longitude = table.Column<double>(type: "double precision", nullable: true),
                    price_level = table.Column<short>(type: "smallint", nullable: true),
                    website_url = table.Column<string>(type: "text", nullable: true),
                    phone = table.Column<string>(type: "text", nullable: true),
                    utc_offset_minutes = table.Column<int>(type: "integer", nullable: true),
                    places_synced_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    type = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    added_by = table.Column<Guid>(type: "uuid", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    entry_count = table.Column<int>(type: "integer", nullable: false),
                    avg_score = table.Column<decimal>(type: "numeric(3,1)", nullable: true),
                    avg_wifi = table.Column<decimal>(type: "numeric(2,1)", nullable: true),
                    avg_noise = table.Column<decimal>(type: "numeric(2,1)", nullable: true),
                    avg_outlets = table.Column<decimal>(type: "numeric(2,1)", nullable: true),
                    avg_seating = table.Column<decimal>(type: "numeric(2,1)", nullable: true),
                    avg_coffee = table.Column<decimal>(type: "numeric(2,1)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_spots", x => x.id);
                    table.CheckConstraint("ck_spots_lat_range", "latitude IS NULL OR latitude BETWEEN -90 AND 90");
                    table.CheckConstraint("ck_spots_lng_range", "longitude IS NULL OR longitude BETWEEN -180 AND 180");
                    table.CheckConstraint("ck_spots_price_range", "price_level IS NULL OR price_level BETWEEN 0 AND 4");
                    table.CheckConstraint("ck_spots_type_valid", "type IN ('cafe', 'library', 'campus', 'other')");
                    table.ForeignKey(
                        name: "fk_spots_users_added_by",
                        column: x => x.added_by,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "spot_entries",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    spot_id = table.Column<Guid>(type: "uuid", nullable: false),
                    wifi = table.Column<short>(type: "smallint", nullable: false),
                    noise = table.Column<short>(type: "smallint", nullable: false),
                    outlets = table.Column<short>(type: "smallint", nullable: false),
                    seating = table.Column<short>(type: "smallint", nullable: false),
                    coffee = table.Column<short>(type: "smallint", nullable: false),
                    score = table.Column<decimal>(type: "numeric(3,1)", nullable: false, computedColumnSql: "round((wifi + noise + outlets + seating + coffee) * 0.4, 1)", stored: true),
                    coffee_order = table.Column<string>(type: "text", nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true),
                    visibility = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_spot_entries", x => x.id);
                    table.CheckConstraint("ck_spot_entries_coffee_range", "coffee BETWEEN 1 AND 5");
                    table.CheckConstraint("ck_spot_entries_noise_range", "noise BETWEEN 1 AND 5");
                    table.CheckConstraint("ck_spot_entries_outlets_range", "outlets BETWEEN 1 AND 5");
                    table.CheckConstraint("ck_spot_entries_seating_range", "seating BETWEEN 1 AND 5");
                    table.CheckConstraint("ck_spot_entries_visibility_valid", "visibility IN ('public', 'followers', 'private')");
                    table.CheckConstraint("ck_spot_entries_wifi_range", "wifi BETWEEN 1 AND 5");
                    table.ForeignKey(
                        name: "fk_spot_entries_spots_spot_id",
                        column: x => x.spot_id,
                        principalTable: "spots",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_spot_entries_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.InsertData(
                table: "users",
                columns: new[] { "id", "auth_provider", "auth_subject", "avatar_url", "bio", "created_at", "deleted_at", "display_name", "email", "handle", "is_private", "updated_at" },
                values: new object[] { new Guid("00000000-0000-0000-0000-0000000000d5"), "dev", "local", null, null, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), null, "Dev User", null, "dev", false, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.CreateIndex(
                name: "ix_spot_entries_spot_id",
                table: "spot_entries",
                column: "spot_id");

            migrationBuilder.CreateIndex(
                name: "ix_spot_entries_user_id_score",
                table: "spot_entries",
                columns: new[] { "user_id", "score" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "ix_spot_entries_user_id_spot_id",
                table: "spot_entries",
                columns: new[] { "user_id", "spot_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_spots_added_by",
                table: "spots",
                column: "added_by");

            migrationBuilder.CreateIndex(
                name: "ix_spots_google_place_id",
                table: "spots",
                column: "google_place_id",
                unique: true,
                filter: "google_place_id IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "ix_spots_type",
                table: "spots",
                column: "type");

            migrationBuilder.CreateIndex(
                name: "ix_users_auth_provider_auth_subject",
                table: "users",
                columns: new[] { "auth_provider", "auth_subject" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_users_handle",
                table: "users",
                column: "handle",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "spot_entries");

            migrationBuilder.DropTable(
                name: "spots");

            migrationBuilder.DropTable(
                name: "users");

            migrationBuilder.CreateTable(
                name: "StudySpots",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Address = table.Column<string>(type: "text", nullable: true),
                    CoffeeQuality = table.Column<int>(type: "integer", nullable: false),
                    DrinkOrder = table.Column<string>(type: "text", nullable: true),
                    ExtraNotes = table.Column<string>(type: "text", nullable: true),
                    GeneralPrice = table.Column<string>(type: "text", nullable: true),
                    HasCharging = table.Column<bool>(type: "boolean", nullable: false),
                    Name = table.Column<string>(type: "text", nullable: true),
                    OpenUntil = table.Column<DateTime>(type: "timestamp without time zone", nullable: false),
                    Seating = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StudySpots", x => x.Id);
                });
        }
    }
}
