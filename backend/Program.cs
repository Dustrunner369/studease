using study_spot_backend;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Middleware
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy  =>
        {
            policy.WithOrigins("http://localhost:4200")
                .AllowAnyHeader()
                .AllowAnyMethod();
        });
});

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

builder.Services.AddDbContext<AppDbContext>(opt => opt.UseNpgsql(connectionString));
builder.Services.AddDatabaseDeveloperPageExceptionFilter();

var app = builder.Build();

// Automatically applies any database migrations at runtime
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.Migrate();
}

// Returns list of study spots
app.MapGet("/studyspots", async (AppDbContext db) =>
    await db.StudySpots.ToListAsync());

// Fetches a study spot by Id
app.MapGet("/studyspots/{id}", async (int id, AppDbContext db) =>
    await db.StudySpots.FindAsync(id)
        is StudySpot studySpot
        ? Results.Ok(studySpot)
        : Results.NotFound());

// Creates a new study spot
app.MapPost("/studyspots", async (StudySpot studySpot, AppDbContext db) =>
{
    db.StudySpots.Add(studySpot);

    await db.SaveChangesAsync();

    return Results.Created($"/studyspots/{studySpot.Id}", studySpot);
});

// Modifies an existing study spot
app.MapPut("/studyspots/{id}", async (int id, StudySpot spotToCreate, AppDbContext db) =>
{
    StudySpot? studySpot = await db.StudySpots.FindAsync(id);

    if (studySpot is null) return Results.NotFound();

    studySpot.Name = spotToCreate.Name;
    studySpot.Address = spotToCreate.Address;
    studySpot.HasCharging = spotToCreate.HasCharging;
    studySpot.Seating = spotToCreate.Seating;
    studySpot.CoffeeQuality = spotToCreate.CoffeeQuality;
    studySpot.GeneralPrice = spotToCreate.GeneralPrice;
    studySpot.OpenUntil = spotToCreate.OpenUntil;
    studySpot.DrinkOrder = spotToCreate.DrinkOrder;
    studySpot.ExtraNotes = spotToCreate.ExtraNotes;

    await db.SaveChangesAsync();

    return Results.NoContent();
});

// Deletes
app.MapDelete("/studyspots/{id}", async (int id, AppDbContext db) =>
{
    if (await db.StudySpots.FindAsync(id) is StudySpot studySpot)
    {
        db.StudySpots.Remove(studySpot);
        await db.SaveChangesAsync();
        return Results.NoContent();
    }

    return Results.NotFound();
});

app.UseCors();

app.Run();