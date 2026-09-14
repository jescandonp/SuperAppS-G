using Sg.SuperApp.Api.Certificates;
using Sg.SuperApp.Api.Contracts.Portal;

var outputDir = args.Length > 0 ? args[0] : Directory.GetCurrentDirectory();
Directory.CreateDirectory(outputDir);

var activo = new CertificateDocumentData(
    CertificateNumber: "SG-I4-99999999-000001",
    CertificateType: "ACTIVO",
    Purpose: "ENTIDAD_FINANCIERA",
    IssueDate: new DateOnly(2026, 9, 14),
    EmployeeFullName: "MARIA FERNANDA GUTIERREZ DE LA ESPRIELLA MONTAÑO",
    IdentificationType: "CC",
    IdentificationNumber: "1.014.287.553",
    HireDate: new DateOnly(2019, 3, 4),
    TerminationDate: null,
    TerminationReason: null,
    JobTitle: "SUPERVISORA DE SEGURIDAD Y VIGILANCIA ZONA NORTE",
    ContractType: "TERMINO INDEFINIDO",
    BaseSalary: 1_623_500m,
    AddressedTo: "BANCO DAVIVIENDA S.A. - AREA DE CREDITO DE LIBRE INVERSION",
    Variables: new List<CertificateVariableResponse>
    {
        new("AUXILIO_TRANSPORTE", "Auxilio de transporte", 200_000m, null),
        new("EXTRAS", "Extras", 412_750m, null)
    },
    SignerFullName: "JORGE ENRIQUE VILLAMIZAR ACOSTA",
    SignerJobTitle: "Subgerente Administrativo.",
    SignerSignaturePath: null,
    PreparedByFullName: "CLAUDIA PATRICIA RUEDA");

var retiradoCesantias = new CertificateDocumentData(
    CertificateNumber: "SG-I4-99999999-000002",
    CertificateType: "RETIRADO",
    Purpose: "CESANTIAS",
    IssueDate: new DateOnly(2026, 9, 14),
    EmployeeFullName: "ORLANDO ESTEBAN CADENA LONDOÑO",
    IdentificationType: "CC",
    IdentificationNumber: "79.548.221",
    HireDate: new DateOnly(2017, 11, 20),
    TerminationDate: new DateOnly(2026, 6, 30),
    TerminationReason: "TERMINACION DE CONTRATO POR MUTUO ACUERDO ENTRE LAS PARTES",
    JobTitle: "GUARDA DE SEGURIDAD",
    ContractType: null,
    BaseSalary: null,
    AddressedTo: null,
    Variables: Array.Empty<CertificateVariableResponse>(),
    SignerFullName: "JORGE ENRIQUE VILLAMIZAR ACOSTA",
    SignerJobTitle: "Subgerente Administrativo",
    SignerSignaturePath: null,
    PreparedByFullName: "CLAUDIA PATRICIA RUEDA");

var retiradoTramiteGeneral = retiradoCesantias with
{
    CertificateNumber = "SG-I4-99999999-000003",
    Purpose = "TRAMITE_GENERAL"
};

WriteCertificate(activo, Path.Combine(outputDir, "activo.pdf"));
WriteCertificate(retiradoCesantias, Path.Combine(outputDir, "retirado-cesantias.pdf"));
WriteCertificate(retiradoTramiteGeneral, Path.Combine(outputDir, "retirado-tramite-general.pdf"));

Console.WriteLine($"OK: 3 certificados escritos en {outputDir}");
return 0;

static void WriteCertificate(CertificateDocumentData data, string path)
{
    var bytes = CertificateDocumentBuilder.Build(data);
    File.WriteAllBytes(path, bytes);
    Console.WriteLine($"  - {Path.GetFileName(path)} ({bytes.Length} bytes)");
}
