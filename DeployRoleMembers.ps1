param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SourceDir,
    [switch]$DeleteAdditional = $false
)

import-module dbatools
$ErrorActionPreference = "stop"

Write-Host "***** DEPLOYING ROLE MEMBERS *****"

Test-DbaConnection $SQLInstance | out-null

# Read source role members from source directory

$roleMembersFile = Join-Path -Path $SourceDir -ChildPath "rolemembers_$Environment.json"
if (-not(Test-Path -path $roleMembersFile)){
    Write-Error "No source file found at $roleMembersFile"
}
Write-Output "Reading source role members from $roleMembersFile."
$sourceRoleMembers = Get-Content $roleMembersFile | ConvertFrom-Json

# Get existing role members from target DB and refactor to match source data structure

Write-Output "Reading existing role members on $SQLInstance.$Database."
$rawDbRoleMembers = Get-DbaDbRoleMember -SqlInstance $SQLInstance -Database $Database

$simpleDbRoleMembers = @()
For ($i=0; $i -lt $rawDbRoleMembers.Length; $i++){    
    # Pulling all the role memberships from the DB
    if ($simpleDbRoleMembers.Role -notcontains $rawDbRoleMembers[$i].Role){
        $tempRole = New-Object PSObject -Property @{
            Role = $rawDbRoleMembers[$i].Role
            Members = @()
        }
        # Adding all the members to the temp role
        For ($j=0; $j -lt $rawDbRoleMembers.Length; $j++){
            if($rawDbRoleMembers[$j].Role -like $rawDbRoleMembers[$i].Role){
                if ($rawDbRoleMembers[$j].UserName -notin $tempRole.Members){
                    $tempRole.Members += $rawDbRoleMembers[$j].UserName
                }
            }
        }
        # Adding the temp role to new members
        $simpleDbRoleMembers = $simpleDbRoleMembers + $tempRole
    }
}

# First, add any role members that dont exist on target

Write-Host "Deploying role members:"

$membersAlreadyInstalledCorrectly = 0
$membersAdded = 0
$membersRemoved = 0

for ($i=0; $i -lt $sourceRoleMembers.Length; $i++){
    $IdMatch = [array]::IndexOf($simpleDbRoleMembers.Role,$sourceRoleMembers[$i].Role)
    if ($IdMatch -eq -1){
        # The role does not have any members on the target database!
        Write-Warning $sourceRoleMembers[$i].Role " does not exist on $SQLInstance.$Database"
        Write-Output "    Unable to add the following members to " $sourceRoleMembers[$i].Role ":"
        foreach ($member in $sourceRoleMembers[$i].Members){
            Write-Output "        - $member"
        }
    }
    else {
        # Add any members that are missing on the target database.
        foreach ($member in $sourceRoleMembers[$i].Members){
            if($member -notin $simpleDbRoleMembers[$IdMatch].Members){
                $msg = "    Adding user $member to role " + $sourceRoleMembers[$i].Role + " on $SQLInstance.$Database."
                Write-Output $msg
                Add-DbaDbRoleMember -SqlInstance $SQLInstance -Database $Database -Role $sourceRoleMembers[$i].Role -User $member
                $membersAdded += 1
            }
            else{
                $msg = "    $member already exists on role " + $sourceRoleMembers[$i].Role + " on $SQLInstance.$Database."
                Write-Output $msg
                $membersAlreadyInstalledCorrectly += 1
            }
        }
    }
}

# Then, check whether any need removing. If $DeleteAdditional, remove - otherwise just warn.

for ($i=0; $i -lt $simpleDbRoleMembers.Length; $i++){
    $IdMatch = [array]::IndexOf($sourceRoleMembers.Role,$simpleDbRoleMembers[$i].Role)
    if ($IdMatch -eq -1){
        # The role does not exist in the source!
        $warning = $simpleDbRoleMembers[$i].Role + " does not have any users in source, but it does have users on $SQLInstance.$Database"
        Write-Warning $warning
        if ($DeleteAdditional){
            $msg = "    Removing the following users from " + $sourceRoleMembers[$i].Role + ":"
            Write-Output $msg
            foreach ($member in $simpleDbRoleMembers[$i].Members){
                Write-Output "        - $member"
                Remove-DbaDbRoleMember -SqlInstance $SQLInstance -Database $Database -Role $sourceRoleMembers[$i].Role -User $member
                $membersRemoved += 1
            }
        }
        else {
            $msg = "    The following users need to be removed from role: " + $sourceRoleMembers[$i].Role + ":"
            Write-Output $msg
            foreach ($member in $simpleDbRoleMembers[$i].Members){
                Write-Output "        - $member"
                $membersRemoved += 1
            }
        }
    }
    else {
        # The role exists in the source
        foreach ($member in $simpleDbRoleMembers[$i].Members){
            if($member -notin $sourceRoleMembers[$IdMatch].Members){
                # The member exists on the target database but not in the source
                $warning = $simpleDbRoleMembers[$i].Role + " contains $member on $SQLInstance.$Database but this role member does not exist in source."
                Write-Warning $warning
                if ($DeleteAdditional){
                    Write-Output "    Removing $member from role " $simpleDbRoleMembers[$i].Role "."
                    Remove-DbaDbRoleMember -SqlInstance $SQLInstance -Database $Database -Role $simpleDbRoleMembers[$i].Role -User $member
                    $membersRemoved += 1
                }
                else {
                    $msg = "    $member needs to be removed from role " + $sourceRoleMembers[$i].Role + "."
                    Write-Output $msg
                    $membersRemoved += 1
                }
            }
        }
    }
}

Write-Output "Summary of deployed role members:"

Write-Output "    $membersAlreadyInstalledCorrectly role member(s) already installed correctly on $SQLInstance.$Database"
Write-Output "    $membersAdded role member(s) added to $SQLInstance.$Database"

if ($DeleteAdditional){
    Write-Output "    $membersRemoved role member(s) removed from $SQLInstance.$Database"
}
else {
    Write-Output "    $membersRemoved role member(s) need to be removed from $SQLInstance.$Database"
}
