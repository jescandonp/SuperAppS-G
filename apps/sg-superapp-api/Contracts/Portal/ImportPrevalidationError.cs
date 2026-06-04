namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record ImportPrevalidationError(
    int RowNumber,
    string FieldName,
    string ErrorType,
    string Message,
    string? OriginalValue);
