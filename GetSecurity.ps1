param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    $OutputDir = ""
)

import-module dbatools
$ErrorActionPreference = "stop"

if ($OutputDir -like ""){
	$OutputDir = Join-Path -Path $PSScriptRoot -ChildPath "output"
}
$OutputDir = Join-Path -Path $OutputDir -ChildPath "$SQLInstance\$Database\source"

If(Test-Path -path $OutputDir){   
    Write-Output "Deleted existing file : $OutputDir"
    Remove-Item -Path $OutputDir -Recurse | out-null  #One way of making sure no output makes it to the console.
    }

Write-Output "Creating output directory: $OutputDir"
New-Item -Path $OutputDir -ItemType Directory | out-null
$usersFile = New-Item -Path $OutputDir\users.json -ItemType File

Write-Output "Reading existing users on $SQLInstance.$Database"
$rawUsers = Get-DbaDbUser -SqlInstance $SQLInstance -Database $Database -ExcludeSystemUser

Write-Output "Reformatting the data."
$simplifiedUsers = @()

foreach ($user in $rawUsers){    
    $tempUser = New-Object PSObject -Property @{
        Name = $user.Name
        Login = $user.Login
        DefaultSchema = $user.DefaultSchema  
        Environment = @()
    }
    $tempUser.Environment = $tempUser.Environment + $Environment
    $simplifiedUsers = $simplifiedUsers + $tempUser
}


$simplifiedUsers =  $simplifiedUsers | ConvertTo-Json 

Write-Output "Writing simplified user data to $usersFile"
$simplifiedUsers | Out-File -FilePath $usersFile