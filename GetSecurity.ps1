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

# Getting all the users
Write-Output "Reading existing users on $SQLInstance.$Database"
$rawUsers = Get-DbaDbUser -SqlInstance $SQLInstance -Database $Database -ExcludeSystemUser

# Simplifying our data
Write-Output "Reformatting the data."
$SimplifiedUsers = @()

foreach ($user in $rawUsers){    
    $tempUser = New-Object PSObject -Property @{
        Name = $user.Name
        Login = $user.Login
        DefaultSchema = $user.DefaultSchema  
        Environment = @()
    }
    $tempUser.Environment = $tempUser.Environment + $Environment
    $SimplifiedUsers = $SimplifiedUsers + $tempUser
}

# Exporting our data
$SimplifiedUsers =  $SimplifiedUsers | ConvertTo-Json 

Write-Output "Writing simplified user data to $UsersFile"
$SimplifiedUsers | Out-File -FilePath $UsersFile