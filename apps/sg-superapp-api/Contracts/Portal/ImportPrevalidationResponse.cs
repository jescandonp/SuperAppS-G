namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record ImportPrevalidationResponse(
    long BatchId,
    string Status,
    string FileName,
    int TotalRecords,
    int ValidRecords,
    int IncompleteRecords,
    int DuplicateRecords,
    int InvalidRecords);
