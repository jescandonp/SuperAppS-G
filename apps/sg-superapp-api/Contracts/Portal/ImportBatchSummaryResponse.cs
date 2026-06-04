namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record ImportBatchSummaryResponse(
    long Id,
    string LoadType,
    string FileName,
    string UploadedBy,
    string Status,
    int TotalRecords,
    int ValidRecords,
    int IncompleteRecords,
    int DuplicateRecords,
    int InvalidRecords,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ImportedAt);
