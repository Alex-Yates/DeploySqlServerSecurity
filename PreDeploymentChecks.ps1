param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SourceDir
)

$errorCount = 0

Write-Output " "
Write-Output "*** CHECK: Do all the required source files exist at $SourceDir ***"

# Reading the source files
Write-Output "Reading source from $SourceDir."
$roleMembersFile = Join-Path -Path $SourceDir -ChildPath "rolemembers_$Environment.json"
if (-not(Test-Path -path $roleMembersFile)){
    $msg = "No source file found for role members at $roleMembersFile"
    Write-Error $msg
    $errorCount += 1
}
else {
    Write-Output "Found file at $roleMembersFile"
}
$usersFile = Join-Path -Path $SourceDir -ChildPath "users.json"
if (-not(Test-Path -path $usersFile)){
    $msg = "No source file found for users at $usersFile"
    Write-Error $msg
    $errorCount += 1
}
else {
    Write-Output "Found file at $usersFile"
}
$sourceUsers = Get-Content $usersFile | ConvertFrom-Json
$sourceRoleMembers = Get-Content $roleMembersFile | ConvertFrom-Json

Write-Output " "
Write-Output "*** CHECK: Do the source files contain any data and it is formatted correctly? ***"
Write-Warning "To do: Verify the source files"

# Checking that logins exist for all users
Write-Output " "
Write-Output "*** CHECK: Do all the required LOGINS exist on $SQLInstance ***"

Write-Output "Reading Logins from $SQLInstance."
$dbLogins = Get-DbaLogin -SqlInstance $SQLInstance

$requiredUsers =  $sourceUsers | Where-Object -Property Environment -like -value $Environment 

$corruptUsers = $requiredUsers | Where-Object -Property Login -notin $dbLogins.Name

if ($corruptUsers.length -gt 0){
    $msg = "There are " + $corruptUsers.length + " currupt users. Please add the following Logins on the server: "
    foreach ($corruptUser in $corruptUsers){
        $msg = $msg + $corruptUser.Login + ", "
    }
    Write-Error $msg 
    $errorCount += 1
    
}
else {
    Write-Output "All required Logins found on $SQLInstance."
}

Write-Output " "
Write-Output "*** CHECK: Do all the required DEFAULT SCHEMAS exist on $SQLInstance ***"
Write-Warning "To do: What's the default schema situation?"

Write-Output " "
Write-Output "*** CHECK: Do all the required ROLES exist on $SQLInstance ***"
Write-Warning "To do: Do all the roles exist?"

if($errorCount -gt 0){
    $errorMsg =  "Failed pre-deployment checks with $errorCount error(s)!"
    
    write-host $errorMsg
    throw $errorMsg
}