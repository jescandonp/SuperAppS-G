namespace Sg.SuperApp.Api.Domain;

public static class TrainingComplianceStatusCalculator
{
    public static (string Status, int DaysUntilExpiry) Calculate(DateOnly expiresAt, DateOnly today)
    {
        var daysUntilExpiry = expiresAt.DayNumber - today.DayNumber;
        var status = daysUntilExpiry switch
        {
            < 0 => "VENCIDO",
            <= 15 => "CRITICO",
            <= 30 => "PREVENTIVO",
            <= 60 => "INFORMATIVO",
            _ => "AL_DIA"
        };

        return (status, daysUntilExpiry);
    }
}
