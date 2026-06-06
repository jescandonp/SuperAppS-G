namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record ImportColumnMappingResponse(
    string SourceHeader,
    string? TargetField,
    string MappingStatus,
    int SourcePosition);
