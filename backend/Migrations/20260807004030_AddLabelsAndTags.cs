using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace study_spot_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddLabelsAndTags : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_spots_type",
                table: "spots");

            migrationBuilder.DropCheckConstraint(
                name: "ck_spots_type_valid",
                table: "spots");

            migrationBuilder.DropColumn(
                name: "type",
                table: "spots");

            migrationBuilder.AddColumn<bool>(
                name: "is_admin",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "labels",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    slug = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    display_name = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    requested_by = table.Column<Guid>(type: "uuid", nullable: true),
                    approved_by = table.Column<Guid>(type: "uuid", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_labels", x => x.id);
                    table.CheckConstraint("ck_labels_slug_format", "slug ~ '^[a-z0-9]{2,30}$'");
                    table.CheckConstraint("ck_labels_status_valid", "status IN ('pending', 'approved', 'rejected')");
                    table.ForeignKey(
                        name: "fk_labels_users_approved_by",
                        column: x => x.approved_by,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_labels_users_requested_by",
                        column: x => x.requested_by,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "spot_entry_tags",
                columns: table => new
                {
                    entries_id = table.Column<Guid>(type: "uuid", nullable: false),
                    tags_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_spot_entry_tags", x => new { x.entries_id, x.tags_id });
                    table.ForeignKey(
                        name: "fk_spot_entry_tags_labels_tags_id",
                        column: x => x.tags_id,
                        principalTable: "labels",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_spot_entry_tags_spot_entries_entries_id",
                        column: x => x.entries_id,
                        principalTable: "spot_entries",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "spot_tag_counts",
                columns: table => new
                {
                    spot_id = table.Column<Guid>(type: "uuid", nullable: false),
                    label_id = table.Column<Guid>(type: "uuid", nullable: false),
                    entry_count = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_spot_tag_counts", x => new { x.spot_id, x.label_id });
                    table.ForeignKey(
                        name: "fk_spot_tag_counts_labels_label_id",
                        column: x => x.label_id,
                        principalTable: "labels",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_spot_tag_counts_spots_spot_id",
                        column: x => x.spot_id,
                        principalTable: "spots",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.UpdateData(
                table: "users",
                keyColumn: "id",
                keyValue: new Guid("00000000-0000-0000-0000-0000000000d5"),
                column: "is_admin",
                value: true);

            migrationBuilder.CreateIndex(
                name: "ix_labels_approved_by",
                table: "labels",
                column: "approved_by");

            migrationBuilder.CreateIndex(
                name: "ix_labels_requested_by",
                table: "labels",
                column: "requested_by");

            migrationBuilder.CreateIndex(
                name: "ix_labels_slug",
                table: "labels",
                column: "slug",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_spot_entry_tags_tags_id",
                table: "spot_entry_tags",
                column: "tags_id");

            migrationBuilder.CreateIndex(
                name: "ix_spot_tag_counts_label_id",
                table: "spot_tag_counts",
                column: "label_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "spot_entry_tags");

            migrationBuilder.DropTable(
                name: "spot_tag_counts");

            migrationBuilder.DropTable(
                name: "labels");

            migrationBuilder.DropColumn(
                name: "is_admin",
                table: "users");

            migrationBuilder.AddColumn<string>(
                name: "type",
                table: "spots",
                type: "character varying(16)",
                maxLength: 16,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "ix_spots_type",
                table: "spots",
                column: "type");

            migrationBuilder.AddCheckConstraint(
                name: "ck_spots_type_valid",
                table: "spots",
                sql: "type IN ('cafe', 'library', 'campus', 'other')");
        }
    }
}
