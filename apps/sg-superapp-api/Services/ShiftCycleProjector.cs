using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed class ShiftCycleProjector
{
    private static readonly HashSet<string> SupportedShiftCodes = new(StringComparer.Ordinal)
    {
        "D",
        "N",
        "X"
    };

    public IReadOnlyList<ProjectedShiftDay> Project(ShiftCycleRequest request)
    {
        if (request.Sequence.Count == 0)
        {
            throw new ArgumentException("La secuencia no puede estar vacia.", nameof(request));
        }

        if (request.Sequence.Any(code => !SupportedShiftCodes.Contains(code)))
        {
            throw new ArgumentException("La secuencia solo admite los codigos D, N y X.", nameof(request));
        }

        if (request.To < request.From)
        {
            throw new ArgumentException("La fecha final no puede ser anterior a la inicial.", nameof(request));
        }

        var dayCount = request.To.DayNumber - request.From.DayNumber + 1;
        return Enumerable.Range(0, dayCount)
            .Select(offset => request.From.AddDays(offset))
            .Select(date =>
            {
                var elapsed = date.DayNumber - request.AnchorDate.DayNumber + request.PhaseOffset;
                var index = ((elapsed % request.Sequence.Count) + request.Sequence.Count) % request.Sequence.Count;
                return new ProjectedShiftDay(date, request.Sequence[index], index);
            })
            .ToArray();
    }
}
