using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace study_spot_backend.Migrations
{
    /// <inheritdoc />
    public partial class SeedLabels : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "labels",
                columns: new[] { "id", "approved_by", "created_at", "display_name", "polarity", "requested_by", "slug", "status", "updated_at" },
                values: new object[,]
                {
                    { new Guid("09c1b8d1-b7fc-45a6-aabc-c6e13968f937"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "great smoothies", "positive", null, "great-smoothies", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("0d0744c6-e6f9-45d0-b30b-27cce17af987"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "loud", "negative", null, "loud", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("0f847955-c6d7-4185-aebb-f36d3c0374a5"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "quiet", "positive", null, "quiet", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("3da0fb71-01b3-4184-9570-1f2e72335a97"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "comfy seating", "positive", null, "comfy-seating", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("45d5905b-0399-41e8-9081-fbd18d2dba23"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "gluten-free", "positive", null, "gluten-free", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("5097f5fc-df27-4fa3-bed1-ddb2dd1f38c9"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "first date", "positive", null, "first-date", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("68c862fd-3683-401f-8b9e-a651f5419fff"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "great pour-over", "positive", null, "great-pour-over", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("74ed637a-9376-458e-b68c-cb5d878adf7f"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "expensive", "negative", null, "expensive", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("860eb038-745f-4b6a-af63-bbe204d0b9aa"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "hard seating", "negative", null, "hard-seating", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("967fded0-094f-479c-ad2e-2e2a70764130"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "great matcha", "positive", null, "great-matcha", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("9903b982-5886-4315-a453-3796c07bb3d7"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "reading nook", "positive", null, "reading-nook", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("9fcb370f-99e3-4709-ad47-fff5dd68b883"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "spacious", "positive", null, "spacious", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("a930da23-d776-4116-aa1e-79c647918b36"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "great latte", "positive", null, "great-latte", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("b98f6021-a30f-4c08-ab59-5a8634095309"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "dim lighting", "negative", null, "dim-lighting", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("bd822f70-112e-4635-b43f-cb5409a0622f"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "industrial", "positive", null, "industrial", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("cc9f75a2-8cae-4227-a975-cab5b1286cc0"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "plants everywhere", "positive", null, "plants-everywhere", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("d2bf3b5b-4c15-4ca5-9bf1-d96cb6eefee9"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "open-air", "positive", null, "open-air", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("d4408705-2f22-46fe-ac04-2a51431fe90a"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "cozy", "positive", null, "cozy", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("f0d157a4-5429-47b1-818c-869a36370fbe"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "aesthetic", "positive", null, "aesthetic", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("f3ef91b9-916e-49d8-a983-bc80c55e4dfb"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "yummy pastries", "positive", null, "yummy-pastries", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("fd23c2f8-ad32-492b-b8b8-5f3df7082289"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "always crowded", "negative", null, "always-crowded", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("fea67674-9df1-470c-83b9-fd0d5cf8296d"), new Guid("00000000-0000-0000-0000-0000000000d5"), new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc), "open late", "positive", null, "open-late", "approved", new DateTime(2026, 8, 31, 0, 0, 0, 0, DateTimeKind.Utc) }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("09c1b8d1-b7fc-45a6-aabc-c6e13968f937"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("0d0744c6-e6f9-45d0-b30b-27cce17af987"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("0f847955-c6d7-4185-aebb-f36d3c0374a5"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("3da0fb71-01b3-4184-9570-1f2e72335a97"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("45d5905b-0399-41e8-9081-fbd18d2dba23"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("5097f5fc-df27-4fa3-bed1-ddb2dd1f38c9"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("68c862fd-3683-401f-8b9e-a651f5419fff"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("74ed637a-9376-458e-b68c-cb5d878adf7f"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("860eb038-745f-4b6a-af63-bbe204d0b9aa"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("967fded0-094f-479c-ad2e-2e2a70764130"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("9903b982-5886-4315-a453-3796c07bb3d7"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("9fcb370f-99e3-4709-ad47-fff5dd68b883"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("a930da23-d776-4116-aa1e-79c647918b36"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("b98f6021-a30f-4c08-ab59-5a8634095309"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("bd822f70-112e-4635-b43f-cb5409a0622f"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("cc9f75a2-8cae-4227-a975-cab5b1286cc0"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("d2bf3b5b-4c15-4ca5-9bf1-d96cb6eefee9"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("d4408705-2f22-46fe-ac04-2a51431fe90a"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("f0d157a4-5429-47b1-818c-869a36370fbe"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("f3ef91b9-916e-49d8-a983-bc80c55e4dfb"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("fd23c2f8-ad32-492b-b8b8-5f3df7082289"));

            migrationBuilder.DeleteData(
                table: "labels",
                keyColumn: "id",
                keyValue: new Guid("fea67674-9df1-470c-83b9-fd0d5cf8296d"));
        }
    }
}
