param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SourceDir,
    [switch]$DeleteAdditional = $false
)

import-module dbatools
$ErrorActionPreference = "stop"

Write-Output ""
Write-Output "***** DEPLOYING USERS FROM $SourceDir TO $Environment.$Database *****"
Write-Output ""

Test-DbaConnection $SQLInstance | out-null

$UsersFile = Join-Path -Path $SourceDir -ChildPath "users.json"

if (-not(Test-Path -path $UsersFile)){
    Write-Error "No source file found at $UsersFile"
}

Write-Output "Reading source users from $UsersFile."
$SourceUsers = Get-Content $UsersFile | ConvertFrom-Json

Write-Output "Reading existing users on $SQLInstance.$Database."
$dbUsers = Get-DbaDbUser -SqlInstance $SQLInstance -Database $Database -ExcludeSystemUser

$usersAlreadyInstalledCorrectly = 0
$usersAdded = 0
$usersWithMisconfiguredDefaultSchemas = 0
$usersWithMisconfiguredDefaultSchemasList = @()
$usersWithMisconfiguredLogins = 0
$usersWithMisconfiguredLoginsList = @()
$usersRemoved = 0

Write-Host "Deploying users:"

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
                $usersWithMisconfiguredDefaultSchemas += 1
                $usersWithMisconfiguredDefaultSchemasList += $user.Name
            }
            # Checking Login matches
            if ($user.Login -notlike $dbUsers[$IdMatch].Login){
                $userMatches = $false
                $warning = $user.Name + " exists in both DB and source but login does not match. "
                $warning = $warning + "The login on the DB is " + $dbUsers[$IdMatch].Login + ". "
                $warning = $warning + "The login in source code is " + $user.Login + ". "
                if ($DeleteAdditional){
                    $warning = $warning + "Dropping the user and re-deploying with the correct login."
                    Write-Warning "D'oh: $warning"
                    Remove-DbaDbUser -User $user.Name -SqlInstance $SQLInstance -Database $Database
                    $msg = "    Re-deploying " + $user.Name 
                    Write-Host $msg
                    New-DbaDbUser -SqlInstance $SQLInstance -Database $Database -Login $user.Login -Username $user.Name -EnableException
                }
                else {
                    $warning = $warning + "This should be rectified manually."
                    Write-Warning "D'oh: $warning"
                }
                $usersWithMisconfiguredLogins += 1 
                $usersWithMisconfiguredLoginsList += $user.Name               
            }
            if ($userMatches){
               $msg = "    " + $user.Name + " already installed correctly." 
               Write-Host $msg
               $usersAlreadyInstalledCorrectly += 1
            }
        }
        else {
            # The user needs to be added
            $msg = "    Deploying " + $user.Name 
            Write-Host $msg
            New-DbaDbUser -SqlInstance $SQLInstance -Database $Database -Login $user.Login -Username $user.Name -EnableException
            $usersAdded += 1
        }
    }
}

ForEach ($user in $dbUsers){
    if ($sourceUsers.Name -notcontains $user.Name){
        # The user should be deleted
        $warning = $user.Name + " exists on database but is not in source control." 
        Write-Warning $warning
        if ($DeleteAdditional){
            $msg = "    Removing " + $user.Name
            Write-Output $msg
            Remove-DbaDbUser -User $user.Name -SqlInstance $SQLInstance -Database $Database
        }
        else {
            $msg = "    You should either add " + $user.Name + " to source control, manually delete it from the target database, or re-run this deployment with the -DeleteAdditional parameter."
            Write-Output $msg
        }
        $usersRemoved += 1
    }
    else {
        # Need to verify if the user is supposed to live in this environment.
        $IdMatch = [array]::IndexOf($sourceUsers.Name,$user.Name)
        if ($sourceUsers[$IdMatch].Environment -notcontains $Environment){
            # The user should be deleted
            $warning = $user.Name + " exists on $SQLInstance.$Database but should not exist in $Environment." 
            Write-Warning $warning
            if ($DeleteAdditional){
                $msg = "    Removing " + $user.Name
                Write-Output $msg
                Remove-DbaDbUser -User $user.Name -SqlInstance $SQLInstance -Database $Database
            }
            else {
                $msg = "    You should either add the environment $Environment to " + $user.Name + " in source control, manually delete it from the target database, or re-run this deployment with the -DeleteAdditional parameter."
                Write-Output $msg
            }
            $usersRemoved += 1
        }
    } 
}

Write-Output "Summary of deployed users:"

Write-Output "    $usersAlreadyInstalledCorrectly user(s) already installed correctly on $SQLInstance.$Database"
Write-Output "    $usersAdded user(s) added to $SQLInstance.$Database"
Write-Output "    $usersWithMisconfiguredDefaultSchemas user(s) exist on $SQLInstance.$Database with misconfigured DEFAULT SCHEMA. Please fix these manually!"
foreach ($user in $usersWithMisconfiguredDefaultSchemasList){
    Write-Output "        - $user"
}
if ($DeleteAdditional){
    Write-Output "    $usersWithMisconfiguredLogins user(s) exist on $SQLInstance.$Database with misconfigured LOGIN. These have been recreated with the correct login."
}
else {
    Write-Output "    $usersWithMisconfiguredLogins user(s) exist on $SQLInstance.$Database with misconfigured LOGIN. Please fix these manually!"
}
foreach ($user in $usersWithMisconfiguredLoginsList){
    Write-Output "        - $user"
}

if ($DeleteAdditional){
    Write-Output "    $usersRemoved role user(s) removed from $SQLInstance.$Database"
}
else {
    Write-Output "    $usersRemoved user(s) need to be removed from $SQLInstance.$Database"
}
