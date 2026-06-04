namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record ImportBatchErrorResponse(
    long Id,
    int RowNumber,
    string FieldName,
    string ErrorType,
    string Message,
    string? OriginalValue);
