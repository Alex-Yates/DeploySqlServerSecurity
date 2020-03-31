param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SourceDir
)

$errorCount = 0
$errorTypes = @()


Write-Output "Reading data from source files."
$sourceUsers = Get-Content $usersFile | ConvertFrom-Json
$sourceRoleMembers = Get-Content $roleMembersFile | ConvertFrom-Json


# Checking that logins exist for all users
Write-Output " "
Write-Output "*** CHECK: Do all the required LOGINS exist on $SQLInstance ***"
Write-Output "Reading LOGINS from $SQLInstance."
$dbLogins = Get-DbaLogin -SqlInstance $SQLInstance
[array]$requiredUsers =  $sourceUsers | Where-Object -Property Environment -like -value $Environment 
[array]$corruptUsers = $requiredUsers | Where-Object -Property Login -notin $dbLogins.Name
if ($corruptUsers.length -gt 0){
    $msg = "Found " + $corruptUsers.length + " currupt user(s) on $SQLInstance. Please add the following LOGINS on the server: "
    foreach ($corruptUser in $corruptUsers){
        $msg = $msg + $corruptUser.Login + ", "
    }
    Write-Error $msg 
    $errorCount += 1
    $errorTypes += " Missing LOGINS on $SQLInstance."
}
else {
    Write-Output "All required LOGINS found on $SQLInstance."
}


Write-Output " "
Write-Output "*** CHECK: Do all the required DEFAULT SCHEMAS exist on $SQLInstance ***"
Write-Warning "To do: What's the default schema situation?"


Write-Output " "
Write-Output "*** CHECK: Do all the required ROLES exist on $SQLInstance ***"
Write-Output "Reading ROLES from $SQLInstance.$Database."
$dbRoles = Get-DbaDbRole -SqlInstance $SQLInstance -Database $Database
[array]$missingRoles = $sourceRoleMembers | Where-Object -Property Role -notin $dbRoles.Name
if ($missingRoles.length -gt 0){
    $msg = "Found " + $missingRoles.length + " missing role(s) on $SQLInstance.$Database. Please add the following ROLES to the database: "
    foreach ($role in $missingRoles.Role){
        $msg = $msg + $role + ", "
    }
    Write-Error $msg 
    $errorCount += 1
    $errorTypes += " Missing ROLES on $SQLInstance.$Database."
}
else {
    Write-Output "All required ROLES found on $SQLInstance."
}


# Throwing error if $errorCount > 0 to ensure DeplpoySecurity.ps1 stops before deployment
if($errorCount -gt 0){
    $errorMsg =  "Failed pre-deployment checks with $errorCount error(s)!:"
    $errorMsg = $errorMsg + $errorTypes
    throw $errorMsg
}