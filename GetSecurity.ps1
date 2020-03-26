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
$SourceUsers = @()
if (Test-Path -path $UsersFile){
    $SourceUsers = Get-Content $UsersFile | ConvertFrom-Json
}

# Merging $DbUsers with $SourceUsers
    <#
    FIRST:
    - Create new empty array for users called $NewUsers
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
         - If $SourceUser.Environment -contains $Environment, remove $Environment.
         - If $SourceUser.Environment not empty, include $sourceUser
    FINALLY:
    - Sort $NewUsers alphabetically by $User.Name
    - Replace $SourceUsers with $NewUsers
     #>

$NewUsers = @()

# Case 1 (See multi-line commen above)
Write-Output "Merging users that exist in both DB and output directory."
For ($i=0; $i -lt $DbUsers.Length; $i++){
        # If there are multiple name matches, this will only find the first one!
    $IdMatch = -1
    if($SourceUsers.Name -contains $DbUsers[$i].Name){
        $msg = "User " + $DbUsers[$i].Name + " already exists in output directory. Merging user properties."
        Write-Output $msg
        $IdMatch = [array]::IndexOf($SourceUsers.Name,$DbUsers[$i].Name)
         # Checking Default schema matches
        if ($DbUsers[$i].DefaultSchema -notlike $SourceUsers[$IdMatch].DefaultSchema){
            $warning = $DbUsers[$i].Name + " exists in both DB and output but Default Schema does not match. "
            $warning = $warning + "The DB version is " + $DbUsers[$i].DefaultSchema + ". "
            $warning = $warning + "The output version is " + $SourceUsers[$IdMatch].DefaultSchema + ". "
            $warning = $warning + "Taking the DB version." 
            Write-Warning "D'oh: $warning"
        }
        # Checking Login matches
        if ($DbUsers[$i].Login -notlike $SourceUsers[$IdMatch].Login){
            $warning = $DbUsers[$i].Name + " exists in both DB and output but Login does not match. "
            $warning = $warning + "The DB version is " + $DbUsers[$i].Login + ". "
            $warning = $warning + "The output version is " + $SourceUsers[$IdMatch].Login + ". "
            $warning = $warning + "Taking the DB version." 
            Write-Warning $warning
        }
    }
    # Creating new user based on DbUser, plus all environments from SourceUser
    $tempUser = New-Object PSObject -Property @{
        Name = $DbUsers[$i].Name
        Login = $DbUsers[$i].Login
        DefaultSchema = $DbUsers[$i].DefaultSchema  
        Environment = @()
    } 
    $tempUser.Environment = $tempUser.Environment + $Environment
    if ($IdMatch -ne -1){
        $tempUser.Environment = $tempUser.Environment + $SourceUsers[$IdMatch].Environment
        $tempUser.Environment = $tempUser.Environment | select -unique
    }
    # Adding new user to $NewUsers
    $NewUsers = $NewUsers + $tempUser  
}
# Case 2 (See multi-line commen above)
Write-Output "Adding users that exist in DB but not in output directory."
Write-Warning "Implement this merge functionality!"

# Case 3 (See multi-line commen above)
Write-Output "Removing users that exist in output directory but do not exist in DB."
Write-Warning "Implement this merge functionality!"

# Removing old UsersFile
if (Test-Path -path $UsersFile){
    Remove-Item $UsersFile 
}

# Exporting our data
$NewUsers = $NewUsers | Sort-Object -Property Name
$NewUsers =  $NewUsers | ConvertTo-Json 

Write-Output "Writing simplified user data to $UsersFile"
$NewUsers | Out-File -FilePath $UsersFile