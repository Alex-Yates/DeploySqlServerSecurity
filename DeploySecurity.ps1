param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SourceDir,
    [switch]$DeleteAdditional = $false
)

$ErrorActionPreference = "stop"

if($DeleteAdditional){
    & $PSScriptRoot\TestSecurity.ps1 -SourceDir $SourceDir -DeleteAdditional
    & $PSScriptRoot\PreDeploymentChecks.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -SourceDir $SourceDir -DeleteAdditional
    & $PSScriptRoot\DeployUsers.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -SourceDir $SourceDir -DeleteAdditional
    & $PSScriptRoot\DeployRoleMembers.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -SourceDir $SourceDir -DeleteAdditional
}
else {
    & $PSScriptRoot\TestSecurity.ps1 -SourceDir $SourceDir
    & $PSScriptRoot\PreDeploymentChecks.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -SourceDir $SourceDir
    & $PSScriptRoot\DeployUsers.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -SourceDir $SourceDir
    & $PSScriptRoot\DeployRoleMembers.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -SourceDir $SourceDir
}