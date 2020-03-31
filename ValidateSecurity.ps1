param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SourceDir
)

# A script to verify that the security on a target database matches the source code.
Write-Output ""
Write-Output "***** VALIDATING $SQLInstance.$Database MATCHES SOURCE CODE AT $SourceDir FOR ENVIRONMENT $Environment *****"
Write-Output ""
Write-Warning "To do: Write the script for ValidateSecurity.ps1"

