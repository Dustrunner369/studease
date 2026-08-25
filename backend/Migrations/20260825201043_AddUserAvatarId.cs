using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace study_spot_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddUserAvatarId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "avatar_id",
                table: "users",
                type: "text",
                nullable: true);

            migrationBuilder.UpdateData(
                table: "users",
                keyColumn: "id",
                keyValue: new Guid("00000000-0000-0000-0000-0000000000d5"),
                column: "avatar_id",
                value: null);

            migrationBuilder.AddCheckConstraint(
                name: "ck_users_avatar_id_valid",
                table: "users",
                sql: "avatar_id IN ('cafe_01', 'cafe_02', 'cafe_03', 'cafe_04', 'cafe_05', 'cafe_06', 'cafe_07', 'cafe_08', 'cafe_09', 'cafe_10') OR avatar_id IS NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_users_avatar_id_valid",
                table: "users");

            migrationBuilder.DropColumn(
                name: "avatar_id",
                table: "users");
        }
    }
}
