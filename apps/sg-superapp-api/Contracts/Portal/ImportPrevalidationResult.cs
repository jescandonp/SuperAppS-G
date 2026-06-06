namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record ImportPrevalidationResult(
    string FileName,
    int TotalRecords,
    int ValidRecords,
    int IncompleteRecords,
    int DuplicateRecords,
    int InvalidRecords,
    IReadOnlyList<ImportPrevalidationError> Errors,
    IReadOnlyList<ImportColumnMappingResponse> Mappings,
    IReadOnlyList<ImportPrevalidationRow> Rows);
