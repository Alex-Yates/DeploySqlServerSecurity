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

# Case 1 and Case 2, see abpove
Write-Output "Adding new users and merging existing users."
For ($i=0; $i -lt $DbUsers.Length; $i++){
        # If there are multiple name matches, this will only find the first one!
    $IdMatch = -1
    if($SourceUsers.Name -contains $DbUsers[$i].Name){
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
        $msg = "Merging existing user properties: " + $DbUsers[$i].Name
        Write-Output $msg
        $tempUser.Environment = $tempUser.Environment + $SourceUsers[$IdMatch].Environment
        $tempUser.Environment = $tempUser.Environment | select -unique
    }
    else{
        $msg = "Adding new user: " + $DbUsers[$i].Name
        Write-Output $msg
    }
    # Adding new user to $NewUsers
    $NewUsers = $NewUsers + $tempUser  
}

# Case 3 (See multi-line comment above)
For ($i=0; $i -lt $SourceUsers.Length; $i++){
    if(($DbUsers.Name -notcontains $SourceUsers[$i].Name) -and ($SourceUsers[$i].Environment -contains $Environment)){
        # Warning the user we are about to remove code from output dir
        $msg = "User " + $SourceUsers[$i].Name + " exists on output directory for environment $Environment, but is not in $SQLInstance.$Database."
        Write-Output $msg
        $warning = "Removing user " + $SourceUsers[$i].Name + " from $Environment environment in output directory."
        Write-Warning $warning
        
        # Creating a revised version of the source user
        $tempUser = New-Object PSObject -Property @{
            Name = $SourceUsers[$i].Name
            Login = $SourceUsers[$i].Login
            DefaultSchema = $SourceUsers[$i].DefaultSchema  
            Environment = $SourceUsers[$i].Environment 
        } 
        # Renmoving $Environment from $tempUser.Environment
        $tempUser.Environment = $tempUser.Environment -ne $Environment
        
        # Only including the source user if it still belongs to at least one environment
        if ($tempUser.Environment.Length -ne 0){
            # The source users still exists in other environments, so it needs to be included
            $NewUsers = $NewUsers + $tempUser  
        }
        else{
            $warning = "User " + $SourceUsers[$i].Name + " no longer exists in any environments. Removing " + $SourceUsers[$i].Name + " from output directory."
            Write-Warning $warning
        }
    }
    if(($DbUsers.Name -notcontains $SourceUsers[$i].Name) -and ($SourceUsers[$i].Environment -notcontains $Environment)){
        # Creating a revised version of the source user
        $tempUser = New-Object PSObject -Property @{
            Name = $SourceUsers[$i].Name
            Login = $SourceUsers[$i].Login
            DefaultSchema = $SourceUsers[$i].DefaultSchema  
            Environment = $SourceUsers[$i].Environment 
        } 
        # Renmoving $Environment from $tempUser.Environment
        $tempUser.Environment = $tempUser.Environment -ne $Environment
        
        # Only including the source user if it still belongs to at least one environment
        if ($tempUser.Environment.Length -ne 0){
            # The source users still exists in other environments, so it needs to be included
            $NewUsers = $NewUsers + $tempUser  
        }
    }
}

# Removing old UsersFile
if (Test-Path -path $UsersFile){
    Remove-Item $UsersFile 
}

# Exporting our data
$NewUsers = $NewUsers | Sort-Object -Property Name
$NewUsers =  $NewUsers | ConvertTo-Json 

Write-Output "Writing simplified user data to $UsersFile"
$NewUsers | Out-File -FilePath $UsersFile