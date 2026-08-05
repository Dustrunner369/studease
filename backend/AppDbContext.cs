using Microsoft.EntityFrameworkCore;
using study_spot_backend.Models;

namespace study_spot_backend
{
    public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
    {
        // No auth yet, so every entry is written as this seeded user. Replaced by the
        // real caller once sign-in exists — see "Still open" in context/README.md.
        public static readonly Guid DevUserId = new("00000000-0000-0000-0000-0000000000d5");

        public DbSet<User> Users => Set<User>();
        public DbSet<Spot> Spots => Set<Spot>();
        public DbSet<SpotEntry> SpotEntries => Set<SpotEntry>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<User>(entity =>
            {
                entity.HasIndex(u => u.Handle).IsUnique();
                entity.HasIndex(u => new { u.AuthProvider, u.AuthSubject }).IsUnique();

                entity.Property(u => u.Handle).HasMaxLength(30);

                entity.HasData(new User
                {
                    Id = DevUserId,
                    Handle = "dev",
                    DisplayName = "Dev User",
                    AuthProvider = "dev",
                    AuthSubject = "local",
                    // Fixed, not DateTime.UtcNow: seed data goes into a migration, and a
                    // migration has to produce the same SQL every time it's generated.
                    CreatedAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                    UpdatedAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                });
            });

            modelBuilder.Entity<Spot>(entity =>
            {
                // Unique only where present, so manually entered spots (which have no
                // Place ID) don't all collide on NULL.
                entity.HasIndex(s => s.GooglePlaceId)
                    .IsUnique()
                    .HasFilter("google_place_id IS NOT NULL");

                entity.HasIndex(s => s.Type);

                entity.Property(s => s.Type).HasMaxLength(16);
                entity.Property(s => s.AvgScore).HasColumnType("numeric(3,1)");
                entity.Property(s => s.AvgWifi).HasColumnType("numeric(2,1)");
                entity.Property(s => s.AvgNoise).HasColumnType("numeric(2,1)");
                entity.Property(s => s.AvgOutlets).HasColumnType("numeric(2,1)");
                entity.Property(s => s.AvgSeating).HasColumnType("numeric(2,1)");
                entity.Property(s => s.AvgTableSize).HasColumnType("numeric(2,1)");
                entity.Property(s => s.AvgCoffee).HasColumnType("numeric(2,1)");

                entity.HasOne<User>()
                    .WithMany()
                    .HasForeignKey(s => s.AddedBy)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.ToTable(t =>
                {
                    t.HasCheckConstraint("ck_spots_type_valid",
                        "type IN ('cafe', 'library', 'campus', 'other')");
                    t.HasCheckConstraint("ck_spots_price_range",
                        "price_level IS NULL OR price_level BETWEEN 0 AND 4");
                    t.HasCheckConstraint("ck_spots_lat_range",
                        "latitude IS NULL OR latitude BETWEEN -90 AND 90");
                    t.HasCheckConstraint("ck_spots_lng_range",
                        "longitude IS NULL OR longitude BETWEEN -180 AND 180");
                });
            });

            modelBuilder.Entity<SpotEntry>(entity =>
            {
                // One entry per user per spot. This constraint is decision D2.
                entity.HasIndex(e => new { e.UserId, e.SpotId }).IsUnique();

                // Drives the ranked Spots tab.
                entity.HasIndex(e => new { e.UserId, e.Score }).IsDescending(false, true);

                entity.HasIndex(e => e.SpotId);

                // Postgres computes the score on every write, so it can never drift
                // from the ratings it's derived from.
                //
                // table_size is rated but NOT part of this expression. The 0.4 puts five
                // 1-5 ratings at exactly 10.0; adding a sixth term would mean dropping and
                // recreating this generated column and rebasing every score already
                // stored. If that trade is ever worth making, the divisor becomes 3.0.
                entity.Property(e => e.Score)
                    .HasColumnType("numeric(3,1)")
                    .HasComputedColumnSql(
                        "round((wifi + noise + outlets + seating + coffee) * 0.4, 1)",
                        stored: true);

                entity.Property(e => e.Visibility).HasMaxLength(16);

                entity.HasOne(e => e.User)
                    .WithMany(u => u.Entries)
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.Spot)
                    .WithMany(s => s.Entries)
                    .HasForeignKey(e => e.SpotId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.ToTable(t =>
                {
                    t.HasCheckConstraint("ck_spot_entries_visibility_valid",
                        "visibility IN ('public', 'followers', 'private')");
                    t.HasCheckConstraint("ck_spot_entries_wifi_range", "wifi BETWEEN 1 AND 5");
                    t.HasCheckConstraint("ck_spot_entries_noise_range", "noise BETWEEN 1 AND 5");
                    t.HasCheckConstraint("ck_spot_entries_outlets_range", "outlets BETWEEN 1 AND 5");
                    t.HasCheckConstraint("ck_spot_entries_seating_range", "seating BETWEEN 1 AND 5");
                    t.HasCheckConstraint("ck_spot_entries_table_size_range", "table_size BETWEEN 1 AND 5");
                    t.HasCheckConstraint("ck_spot_entries_coffee_range", "coffee BETWEEN 1 AND 5");
                });
            });
        }

        public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        {
            StampTimestamps();
            return base.SaveChangesAsync(cancellationToken);
        }

        public override int SaveChanges()
        {
            StampTimestamps();
            return base.SaveChanges();
        }

        // context/schema.sql keeps updated_at current with a Postgres trigger. Doing it
        // here instead keeps the behaviour visible in C# rather than buried in SQL.
        private void StampTimestamps()
        {
            var now = DateTime.UtcNow;

            foreach (var entry in ChangeTracker.Entries<ITimestamped>())
            {
                if (entry.State == EntityState.Added) entry.Entity.CreatedAt = now;
                if (entry.State is EntityState.Added or EntityState.Modified) entry.Entity.UpdatedAt = now;
            }
        }
    }
}
