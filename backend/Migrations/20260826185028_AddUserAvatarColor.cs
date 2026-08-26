using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace study_spot_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddUserAvatarColor : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "avatar_background_tint",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "avatar_color",
                table: "users",
                type: "text",
                nullable: true);

            migrationBuilder.UpdateData(
                table: "users",
                keyColumn: "id",
                keyValue: new Guid("00000000-0000-0000-0000-0000000000d5"),
                column: "avatar_color",
                value: null);

            migrationBuilder.AddCheckConstraint(
                name: "ck_users_avatar_color_valid",
                table: "users",
                sql: "avatar_color IN ('terracotta', 'slate', 'sage', 'plum', 'cranberry', 'mustard', 'forest', 'denim') OR avatar_color IS NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_users_avatar_color_valid",
                table: "users");

            migrationBuilder.DropColumn(
                name: "avatar_background_tint",
                table: "users");

            migrationBuilder.DropColumn(
                name: "avatar_color",
                table: "users");
        }
    }
}
