param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    $OutputDir = ""
)

import-module dbatools
$ErrorActionPreference = "stop"

# Making the output directory
if ($OutputDir -like ""){
	$OutputDir = Join-Path -Path $PSScriptRoot -ChildPath "output"
}
$OutputDir = Join-Path -Path $OutputDir -ChildPath "$SQLInstance\$Database\source"
$UsersFile = Join-Path -Path $OutputDir -ChildPath "users.json"

If(Test-Path -path $OutputDir){   
    Write-Output "Output directory already exists: $OutputDir" 
}
else {
    Write-Output "Creating output directory: $OutputDir"
    New-Item -Path $OutputDir -ItemType Directory | out-null
}

# Getting all the user data from the DB
Write-Output "Reading existing users on $SQLInstance.$Database"
$rawDbUsers = Get-DbaDbUser -SqlInstance $SQLInstance -Database $Database -ExcludeSystemUser

# Data in rawDbUsers is complicated. Simplifying it.
Write-Output "Simplifying the data."
$DbUsers = @()

foreach ($user in $rawDbUsers){    
    $tempUser = New-Object PSObject -Property @{
        Name = $user.Name
        Login = $user.Login
        DefaultSchema = $user.DefaultSchema  
        Environment = @()
    }
    $tempUser.Environment = $tempUser.Environment + $Environment
    $DbUsers = $DbUsers + $tempUser
}

# Getting all the existing data from $UsersFile
Write-Output "Merging with existing source data."
if (Test-Path -path $UsersFile){
    $SourceUsers = Get-Content $UsersFile | ConvertFrom-Json

# Merging $DbUsers with $SourceUsers

    <#
    FIRST: Create new empty array for users called $NewUsers
    THEN:
        CASE 1: User.Name exists in both DbUsers and SourceUsers
         - Verify all details match. If not, write-warning.
         - Create NewUser, based on DbUser version.
         - Add all additional environments from $SourceUser.Environment 
         - Add $NewUser to $NewUsers. 
        CASE 2: User.Name exists in DbUsers but not SourceUsers
         - Create NewUser, based on DbUser version.
         - Add $NewUser to $NewUsers. 
        CASE 3: User.Name exists in SourceUsers but not DbUsers
         - If $SourceUser.Environment -contains $Environent, remove $Environment.
         - If $SourceUser.Environment not empty, include $sourceUser
    THEN:
    - Sort $NewUsers alphabetically by $User.Name
    - Replace $SourceUsers with $NewUsers
     #>

Write-Output "Merging DB users and existing source users."
$NewUsers = @()

Write-Warning "Implement merge functionality!"

# Exporting our data
$NewUsers =  $NewUsers | ConvertTo-Json 

Write-Output "Writing simplified user data to $UsersFile"
$NewUsers | Out-File -FilePath $UsersFile