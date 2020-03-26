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

$UsersFile = Join-Path -Path $SourceDir -ChildPath "users.json"

if (-not(Test-Path -path $UsersFile)){
    Write-Error "No source file found at $UsersFile"
}

Write-Output "Reading source users"
$SourceUsers = Get-Content $UsersFile | ConvertFrom-Json

Write-Output "Reading existing users on $SQLInstance.$Database"
$dbUsers = Get-DbaDbUser -SqlInstance $SQLInstance -Database $Database -ExcludeSystemUser

ForEach ($user in $SourceUsers){
    if ($user.Environment -contains $Environment){
        # The user should exist on the target database
        if ($dbUsers.Name -contains $user.Name){
            # The user already exists. Need to verify it's configured correctly.
            $IdMatch = [array]::IndexOf($dbUsers.Name,$user.Name)
            $userMatches = $true
            if ($user.DefaultSchema -notlike $dbUsers[$IdMatch].DefaultSchema){
                $userMatches = $false
                $warning = $user.Name + " exists in both DB and source but Default Schema does not match. "
                $warning = $warning + "The default schema on the DB is " + $dbUsers[$IdMatch].DefaultSchema + ". "
                $warning = $warning + "The default schema in source code is " + $user.DefaultSchema + ". "
                $warning = $warning + "This should be rectified manually." 
                Write-Warning "D'oh: $warning"
                
            }
            # Checking Login matches
            if ($user.Login -notlike $dbUsers[$IdMatch].Login){
                $userMatches = $false
                $warning = $user.Name + " exists in both DB and source but login does not match. "
                $warning = $warning + "The login on the DB is " + $dbUsers[$IdMatch].Login + ". "
                $warning = $warning + "The login in source code is " + $user.Login + ". "
                $warning = $warning + "Dropping the user and re-deploying with the correct login." 
                Write-Warning "D'oh: $warning"
                Remove-DbaDbUser -User $user.Name -SqlInstance $SQLInstance -Database $Database
                $msg = "Re-deploying " + $user.Name 
                Write-Host $msg
                New-DbaDbUser -SqlInstance $SQLInstance -Database $Database -Login $user.Login -Username $user.Name                
            }
            if ($userMatches){
               $msg = $user.Name + " already installed correctly." 
               Write-Host $msg
            }
        }
        else {
            # The user needs to be added
            $msg = "Deploying " + $user.Name 
            Write-Host $msg
            New-DbaDbUser -SqlInstance $SQLInstance -Database $Database -Login $user.Login -Username $user.Name
        }
    }
}

ForEach ($user in $dbUsers){
    if ($sourceUsers.Name -notcontains $user.Name){
        # The user should be deleted
        $warning = $user.Name + " exists on database but is not in source control." 
        Write-Warning $warning
        if ($DeleteAdditional){
            $msg = "Removing " + $user.Name
            Write-Output $msg
            Remove-DbaDbUser -User $user.Name -SqlInstance $SQLInstance -Database $Database
        }
        else {
            $msg = "You should either add " + $user.Name + " to source control, manually delete it from the target database, or re-run this deployment with the -DeleteAdditional parameter."
            Write-Output $msg
        }
    }
    else {
        # Need to verify if the user is supposed to live in this environment.
        $IdMatch = [array]::IndexOf($sourceUsers.Name,$user.Name)
        if ($sourceUsers[$IdMatch].Environment -notcontains $Environment){
            # The user should be deleted
            $warning = $user.Name + " exists on $SQLInstance.$Database but should not exist in $Environment." 
            Write-Warning $warning
            if ($DeleteAdditional){
                $msg = "Removing " + $user.Name
                Write-Output $msg
                Remove-DbaDbUser -User $user.Name -SqlInstance $SQLInstance -Database $Database
            }
            else {
                $msg = "You should either add the environment $Environment to " + $user.Name + " in source control, manually delete it from the target database, or re-run this deployment with the -DeleteAdditional parameter."
                Write-Output $msg
            }
        }
    } 
}

