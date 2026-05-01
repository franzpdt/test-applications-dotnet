using Microsoft.EntityFrameworkCore;
using Serilog;
using TaskApi.Data;
using TaskApi.Models;

// Configuration from environment variables
var port = Environment.GetEnvironmentVariable("APP_PORT") ?? "5000";
var logPath = Environment.GetEnvironmentVariable("APP_LOG_PATH") ?? "./logs";

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.Console()
    .WriteTo.File(Path.Combine(logPath, "taskapi-.log"), rollingInterval: RollingInterval.Day)
    .CreateLogger();

try
{
    Log.Information("Starting TaskApi on port {Port}, logs at {LogPath}", port, logPath);

    var builder = WebApplication.CreateBuilder(args);
    builder.Host.UseSerilog();

    builder.Services.AddDbContext<TaskDbContext>(options =>
        options.UseInMemoryDatabase("TaskDb"));

    builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

    var app = builder.Build();

    // Seed database
    using (var scope = app.Services.CreateScope())
    {
        var db = scope.ServiceProvider.GetRequiredService<TaskDbContext>();
        if (!db.Tasks.Any())
        {
            db.Tasks.AddRange(
                new TaskItem { Title = "Buy groceries", Description = "Milk, eggs, bread", IsCompleted = false },
                new TaskItem { Title = "Clean the house", Description = "Vacuum and mop all rooms", IsCompleted = false },
                new TaskItem { Title = "Read a book", Description = "Finish chapter 5 of Clean Code", IsCompleted = true },
                new TaskItem { Title = "Write unit tests", Description = "Cover the TaskApi endpoints", IsCompleted = false },
                new TaskItem { Title = "Go for a run", Description = "5km evening run", IsCompleted = true }
            );
            db.SaveChanges();
            Log.Information("Seeded {Count} default tasks", 5);
        }
    }

    // GET all tasks
    app.MapGet("/api/tasks", async (TaskDbContext db) =>
    {
        Log.Information("GET /api/tasks");
        return Results.Ok(await db.Tasks.ToListAsync());
    });

    // GET task by id
    app.MapGet("/api/tasks/{id:int}", async (int id, TaskDbContext db) =>
    {
        Log.Information("GET /api/tasks/{Id}", id);
        var task = await db.Tasks.FindAsync(id);
        return task is not null ? Results.Ok(task) : Results.NotFound();
    });

    // POST create task
    app.MapPost("/api/tasks", async (TaskItem task, TaskDbContext db) =>
    {
        task.CreatedAt = DateTime.UtcNow;
        db.Tasks.Add(task);
        await db.SaveChangesAsync();
        Log.Information("Created task {Id}: {Title}", task.Id, task.Title);
        return Results.Created($"/api/tasks/{task.Id}", task);
    });

    // PUT update task
    app.MapPut("/api/tasks/{id:int}", async (int id, TaskItem input, TaskDbContext db) =>
    {
        var task = await db.Tasks.FindAsync(id);
        if (task is null) return Results.NotFound();

        task.Title = input.Title;
        task.Description = input.Description;
        task.IsCompleted = input.IsCompleted;
        await db.SaveChangesAsync();
        Log.Information("Updated task {Id}", id);
        return Results.Ok(task);
    });

    // DELETE task
    app.MapDelete("/api/tasks/{id:int}", async (int id, TaskDbContext db) =>
    {
        var task = await db.Tasks.FindAsync(id);
        if (task is null) return Results.NotFound();

        db.Tasks.Remove(task);
        await db.SaveChangesAsync();
        Log.Information("Deleted task {Id}", id);
        return Results.NoContent();
    });

    // CPU stress endpoint
    app.MapGet("/api/stress/cpu", (int seconds = 10) =>
    {
        if (seconds < 1 || seconds > 300)
            return Results.BadRequest("seconds must be between 1 and 300");

        Log.Information("CPU stress started for {Seconds}s", seconds);
        var deadline = DateTime.UtcNow.AddSeconds(seconds);
        long iterations = 0;
        while (DateTime.UtcNow < deadline)
        {
            // Busy-loop to saturate one CPU core
            Math.Sqrt(iterations++);
        }
        Log.Information("CPU stress finished after {Seconds}s ({Iterations} iterations)", seconds, iterations);
        return Results.Ok(new { seconds, iterations });
    });

    // Memory stress endpoint
    app.MapGet("/api/stress/memory", async (int seconds = 10) =>
    {
        if (seconds < 1 || seconds > 300)
            return Results.BadRequest("seconds must be between 1 and 300");

        Log.Information("Memory stress started for {Seconds}s", seconds);
        var chunks = new List<byte[]>();
        var deadline = DateTime.UtcNow.AddSeconds(seconds);
        while (DateTime.UtcNow < deadline)
        {
            // Allocate 10 MB per iteration and touch every page to ensure it is resident
            var chunk = new byte[10 * 1024 * 1024];
            Random.Shared.NextBytes(chunk);
            chunks.Add(chunk);
            await Task.Delay(500);
        }
        var totalMb = chunks.Count * 10;
        Log.Information("Memory stress finished after {Seconds}s ({TotalMb} MB allocated)", seconds, totalMb);
        return Results.Ok(new { seconds, allocatedMb = totalMb });
    });

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
