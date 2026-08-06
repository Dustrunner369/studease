using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace study_spot_backend.Migrations
{
    /// <inheritdoc />
    public partial class AddGuestAuth : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Hand-edited: EF scaffolded an UpdateData call here with an empty column
            // list (HasData's seed row didn't change, only the model around it did) -
            // `UPDATE users SET  WHERE id = ...` is a Postgres syntax error. Removed;
            // there is nothing to update.

            migrationBuilder.AddColumn<bool>(
                name: "is_guest",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddCheckConstraint(
                name: "ck_users_handle_format",
                table: "users",
                sql: "handle ~ '^[a-z0-9_]{3,30}$'");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_users_handle_format",
                table: "users");

            migrationBuilder.DropColumn(
                name: "is_guest",
                table: "users");
        }
    }
}
