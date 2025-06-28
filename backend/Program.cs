using study_spot_backend;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDbContext<AppDbContext>(opt => opt.UseInMemoryDatabase("TodoList"));
builder.Services.AddDatabaseDeveloperPageExceptionFilter();
var app = builder.Build();

app.MapGet("/studyspots", async (AppDbContext db) =>
    await db.StudySpots.ToListAsync());

// app.MapGet("/todoitems/complete", async (AppDbContext db) =>
//     await db.StudySpots.Where(t => t.IsComplete).ToListAsync());
//
// app.MapGet("/todoitems/{id}", async (int id, AppDbContext db) =>
//     await db.StudySpots.FindAsync(id)
//         is StudySpot studySpot
//         ? Results.Ok(studySpot)
//         : Results.NotFound());
//
app.MapPost("/studyspots", async (StudySpot studySpot, AppDbContext db) =>
{
    db.StudySpots.Add(studySpot);
    await db.SaveChangesAsync();

    return Results.Created($"/studyspots/{studySpot.Id}", studySpot);
});

// app.MapPut("/todoitems/{id}", async (int id, Todo inputTodo, AppDbContext db) =>
// {
//     var todo = await db.StudySpots.FindAsync(id);
//
//     if (todo is null) return Results.NotFound();
//
//     todo.Name = inputTodo.Name;
//     //todo.IsComplete = inputTodo.IsComplete;
//
//     await db.SaveChangesAsync();
//
//     return Results.NoContent();
// });

// app.MapDelete("/todoitems/{id}", async (int id, AppDbContext db) =>
// {
//     if (await db.StudySpots.FindAsync(id) is Todo todo)
//     {
//         db.StudySpots.Remove(todo);
//         await db.SaveChangesAsync();
//         return Results.NoContent();
//     }
//
//     return Results.NotFound();
// });

app.Run();