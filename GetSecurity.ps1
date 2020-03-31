param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    $OutputDir = ""
)

$ErrorActionPreference = "stop"

if ($OutputDir -like ""){
	$OutputDir = Join-Path -Path $PSScriptRoot -ChildPath "output"
}

& $PSScriptRoot\GetUsers.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -OutputDir $OutputDir
& $PSScriptRoot\GetRoleMembers.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -OutputDir $OutputDir
& $PSScriptRoot\TestSecurity.ps1 -SourceDir $OutputDir -Environment $Environment