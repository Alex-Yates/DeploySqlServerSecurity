param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    $OutputDir = ""
)

import-module dbatools
$ErrorActionPreference = "stop"

Test-DbaConnection $SQLInstance | out-null

# Making the output directory
if ($OutputDir -like ""){
	$OutputDir = Join-Path -Path $PSScriptRoot -ChildPath "output"
}
$RoleMembersFile = Join-Path -Path $OutputDir -ChildPath "rolemembers_$Environment.json"

# Reading the db role members
$dbRoleMembers = Get-DbaDbRoleMember -SqlInstance $SQLInstance -Database $Database

if (Test-Path -path $RoleMembersFile){
    $sourceRoleMembers = Get-Content $RoleMembersFile | ConvertFrom-Json
}

$newRoleMembers = @()

For ($i=0; $i -lt $dbRoleMembers.Length; $i++){    
    # If the role is not yet added to $newRoleMembers, add it.
    if ($newRoleMembers.Role -notcontains $dbRoleMembers[$i].Role){
        $tempRole = New-Object PSObject -Property @{
            Role = $dbRoleMembers[$i].Role
            Members = @()
        }
        # Adding all the members to the temp role
        For ($j=0; $j -lt $dbRoleMembers.Length; $j++){
            if($dbRoleMembers[$j].Role -like $dbRoleMembers[$i].Role){
                if ($dbRoleMembers[$j].UserName -notin $tempRole.Members){
                    $tempRole.Members += $dbRoleMembers[$j].UserName
                }
            }
        }
        $tempRole.Members = $tempRole.Members | Sort-Object
        # Adding the temp role to new members
        $newRoleMembers = $newRoleMembers + $tempRole
    }
}

Write-Host "ToDo: Sane merge dbRoleMembers with sourceRoleMemebers - rather than drop create"

Write-Host "Total roles: " $newRoleMembers.length

$newRoleMembers = $newRoleMembers | Sort-Object -Property Name
$newRoleMembers = $newRoleMembers | ConvertTo-Json

$newRoleMembers | Out-File -FilePath $RoleMembersFile