param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SourceDir
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
               $msg = $user.Name + "already installed correctly." 
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