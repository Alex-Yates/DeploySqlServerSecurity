param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SourceDir,
    [switch]$DeleteAdditional = $false
)


import-module dbatools
$ErrorActionPreference = "stop"

Test-DbaConnection $SQLInstance | out-null

$RoleMembersFile = Join-Path -Path $SourceDir -ChildPath "rolemembers_$Environment.json"

if (-not(Test-Path -path $RoleMembersFile)){
    Write-Error "No source file found at $RoleMembersFile"
}

Write-Output "Reading source users"
$SourceRoleMembers = Get-Content $RoleMembersFile | ConvertFrom-Json

Write-Warning "To do: Write the code to deplopy role members"