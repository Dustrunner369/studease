namespace study_spot_backend;

public class StudySpot
{
    public int Id { get; set; }
    public string? Name { get; set; }
    public string? Address { get; set; }
    public bool HasCharging { get; set; }
    public int Seating { get; set; }
    public int CoffeeQuality { get; set; }
    public string? GeneralPrice { get; set; }
    public TimeSpan OpenUntil { get; set; }
    public string? DrinkOrder { get; set; }
    public string? ExtraNotes { get; set; }
}