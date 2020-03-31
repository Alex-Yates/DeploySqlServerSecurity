param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    $OutputDir = ""
)

import-module dbatools
$ErrorActionPreference = "stop"

Write-Output ""
Write-Output "***** EXPORTING ROLE MEMBERS FROM $Environment.$Database TO $SourceDir *****"
Write-Output ""

Test-DbaConnection $SQLInstance | out-null

# Making the output directory
if ($OutputDir -like ""){
	$OutputDir = Join-Path -Path $PSScriptRoot -ChildPath "output"
}
$RoleMembersFile = Join-Path -Path $OutputDir -ChildPath "rolemembers_$Environment.json"

$logFile = Join-Path $OutputDir -ChildPath "log.txt"

# Reading the db role members
$dbRoleMembers = Get-DbaDbRoleMember -SqlInstance $SQLInstance -Database $Database

if (Test-Path -path $RoleMembersFile){
    $sourceRoleMembers = Get-Content $RoleMembersFile | ConvertFrom-Json
}

$newRoleMembers = @()

For ($i=0; $i -lt $dbRoleMembers.Length; $i++){    
    # Pulling all the role memberships from the DB
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


Write-Host $sourceRoleMembers.length "roles already exist in source"
# CASE exists in both source and db: Take the new (db) version
For ($i=0; $i -lt $newRoleMembers.Length; $i++){
    if ($sourceRoleMembers.Role -contains $newRoleMembers[$i].Role){
        $IdMatch = [array]::IndexOf($sourceRoleMembers.Role,$newRoleMembers[$i].Role)
        if (Compare-Object $sourceRoleMembers[$IdMatch].Members $newRoleMembers[$i].Members) {
            # Warning
            $warning = $newRoleMembers[$i].Role + " already exists in source but the values do not match!"
            Write-Warning $warning
            Write-Host "    Updating source to match DB version."
            Write-Host "    For more detail, see log file at: $logFile"
            
            # Logging
            Get-Date -Format "yyyy/MM/dd HH:mm:ss" | Out-File -FilePath $logFile -Append
            $newRoleMembers[$i].Role + " role already exists in source but the members do not match." | Out-File -FilePath $logFile -Append
            "    Updating source to match DB version" | Out-File -FilePath $logFile -Append
            "    Details (Arrows pointing left: member removed from role. Arrows pointing right: member added to role):" | Out-File -FilePath $logFile -Append
            Compare-Object $sourceRoleMembers[$IdMatch].Members $newRoleMembers[$i].Members | Out-File -FilePath $logFile -Append
        }
        else {
            Write-Host $newRoleMembers[$i].Role " already exists in source and the members match."
        }
    }
    else {
        Write-Host "Adding " $newRoleMembers[$i].Role " to source."
    }
}

# CASE role exists in source but not db: Remove from source version
For ($i=0; $i -lt $sourceRoleMembers.Length; $i++){
    if ($newRoleMembers.Role -notcontains $sourceRoleMembers[$i].Role){
        # Warning
        $warning = "Removing all members of " + $sourceRoleMembers[$i].Role + " from source because they do not exist in DB."
        Write-Warning $warning
        Write-Host "    For more detail, see log file at: $logFile"

        # Logging
        Get-Date -Format "yyyy/MM/dd HH:mm:ss" | Out-File -FilePath $logFile -Append
        "    Removing all members of " + $sourceRoleMembers[$i].Role + " from source because they do not exist in DB." | Out-File -FilePath $logFile -Append
        "    " + $sourceRoleMembers[$i].Role + " had the following members:" | Out-File -FilePath $logFile -Append
        foreach ($member in $sourceRoleMembers[$i].Members){
            "        " + $member | Out-File -FilePath $logFile -Append
        }
    }
}

Write-Host "Total roles now in source: " $newRoleMembers.length

$newRoleMembers = $newRoleMembers | Sort-Object -Property Name
$newRoleMembers = $newRoleMembers | ConvertTo-Json

$newRoleMembers | Out-File -FilePath $RoleMembersFile