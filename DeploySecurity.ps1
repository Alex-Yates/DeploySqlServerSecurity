param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SourceDir,
    [switch]$DeleteAdditional = $false
)

$ErrorActionPreference = "stop"

# Check everything is in order
& $PSScriptRoot\TestSecurity.ps1 -SourceDir $SourceDir -Environment $Environment
& $PSScriptRoot\PreDeploymentChecks.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -SourceDir $SourceDir

# Perform the deployment
if($DeleteAdditional){
    & $PSScriptRoot\DeployUsers.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -SourceDir $SourceDir -DeleteAdditional
    & $PSScriptRoot\DeployRoleMembers.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -SourceDir $SourceDir -DeleteAdditional
}
else {
    & $PSScriptRoot\DeployUsers.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -SourceDir $SourceDir
    & $PSScriptRoot\DeployRoleMembers.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -SourceDir $SourceDir
}

# Check everything looks like it should
& $PSScriptRoot\ValidateSecurity.ps1 -SQLInstance $SQLInstance -Database $Database -Environment $Environment -SourceDir $SourceDir