param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SourceDir,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment
)

Write-Output ""
Write-Output "***** TESTING SOURCE CODE AT $SourceDir FOR ENVIRONMENT $Environment *****"
Write-Output ""

$errorCount = 0
$errorTypes = @()

Write-Output " "
Write-Output "*** TEST: Do all the required source files exist at $SourceDir ***"
$roleMembersFile = Join-Path -Path $SourceDir -ChildPath "rolemembers_$Environment.json"
if (-not(Test-Path -path $roleMembersFile)){
    $msg = "No source file found for role members at $roleMembersFile"
    Write-Error $msg
    $errorCount += 1
    $errorTypes += " No role members file found at $roleMembersFile."
}
else {
    Write-Output "Found file at $roleMembersFile"
}
$usersFile = Join-Path -Path $SourceDir -ChildPath "users.json"
if (-not(Test-Path -path $usersFile)){
    $msg = "No source file found for users at $usersFile"
    Write-Error $msg
    $errorCount += 1
    $errorTypes += " No users file found at $SourceDir."
}
else {
    Write-Output "Found file at $usersFile"
}

# # This check seems to be broken on my machine. 
# # Possibly something to do with Test-Json only supported on later versions
# # Possibly something to do with me having weird broken install of PS
# # I've created a github issue to look into it here:
# # https://github.com/Alex-Yates/DeploySqlServerSecurity/issues/7
#$MajorPsVersion = $PSVersionTable.PSVersion.Major
#$MinorPsVersion = $PSVersionTable.PSVersion.Minor
#if(($MajorPsVersion -gt 6) -or (($MajorPsVersion -eq 6) -and ($MinorPsVersion -ge 1))){
#    Write-Output " "
#    Write-Output "*** CHECK: Do the source files contain valid syntax? ***"
#    if ($roleMembersFile | Test-Json){
#        Write-Output "$roleMembersFile contains valid JSON syntax." 
#    }
#    else {
#        $msg = "$roleMembersFile does not contain valid JSON syntax. Please inspect file and correct errors."
#        Write-Error $msg 
#        $errorCount += 1
#        $errorTypes += " $roleMembersFile incorrectly formatted."
#    }
#    if ($usersFile | Test-Json){
#        Write-Output "$userFile contains valid JSON syntax.." 
#    }
#    else {
#        $msg = "$usersFile does not contain valid JSON syntax. Please inspect file and correct errors."
#        Write-Error $msg 
#        $errorCount += 1
#        $errorTypes += " $usersFile incorrectly formatted."  
#    }
#}
#else {
#    Write-Warning "Check for valid JSON syntax skipped because the cmdlet Test-Json required PowerShell v6.1 (This machine is only running PowerShell v$MajorPsVersion.$MinorPsVersion.)"
#}


Write-Output "Reading data from source files."
$sourceUsers = Get-Content $usersFile | ConvertFrom-Json
$sourceRoleMembers = Get-Content $roleMembersFile | ConvertFrom-Json


Write-Output " "
Write-Output "*** TEST: Do all the role members exist in $usersFile ***"
$requiredUsers = @()
# Finding all the role members in $sourceRoleMembers
foreach ($role in $sourceRoleMembers){
    $requiredUsers = $requiredUsers + $role.Members
}
# Removing duplicates
$requiredUsers = $requiredUsers | Sort-Object -unique
# Of the source users, checking which exist in the given $Environment
[array]$envSourceUsers = $sourceUsers | Where-Object -Property Environment -like $Environment
# Getting a list of any $requiredUsers
[array]$missingUsers = $requiredUsers | Where-Object {$_ -notin $envSourceUsers.Name}
if ($missingUsers.length -gt 0){
    $msg = "Found " + $missingUsers.length + " missing USER(S) in $usersFile. Please add the following USER(S) and ensure they are included in the $Environment Environment: "
    foreach ($user in $missingUsers){
        $msg = $msg + $user + ", "
    }
    Write-Error $msg 
    $errorCount += 1
    $errorTypes += " Missing " + $missingUsers.length + " USERS in $usersFile."
}
else {
    Write-Output "All required USERS for $Environment found in $usersFile."
}

Write-Output " "
Write-Output "*** TEST: Check for any corrupt USERS (USERS without LOGINS) ***"
[array]$corruptUsers = $sourceUsers | Where-Object -Property Login -like ""
if ($corruptUsers.length -gt 0){
    $msg = "Found " + $corruptUsers.length + " corrupt USER(S) in $usersFile. Please add a LOGIN for each of the following users: "
    foreach ($user in $corruptUsers){
        $msg = $msg + $user.Name + ", "
    }
    Write-Error $msg 
    $errorCount += 1
    $errorTypes += " Found " + $corruptUsers.length + " corrupt USERS in $usersFile."
}
else {
    Write-Output "All USERS in $usersFile have LOGINS."
}

Write-Output " "
Write-Output "*** TEST: Check for any USERS without a DEFAULT SCHEMA ***"
[array]$usersWithoutDefaultSchema = $sourceUsers | Where-Object -Property DefaultSchema -like ""
if ($usersWithoutDefaultSchema.length -gt 0){
    $msg = "Found " + $usersWithoutDefaultSchema.length + " USERS without a DEFAULT SCHEMA in $usersFile. Please add a DEFAULT SCHEMA for each of the following users: "
    foreach ($user in $usersWithoutDefaultSchema){
        $msg = $msg + $user.Name + ", "
    }
    Write-Error $msg 
    $errorCount += 1
    $errorTypes += " Found " + $usersWithoutDefaultSchema.length + " USERS without a DEFAULT SCHEMA in $usersFile."
}
else {
    Write-Output "All USERS in $usersFile have a DEFAULT SCHEMA."
}

Write-Output " "
Write-Output "*** TEST: Check for any USERS with DEFAULT SCHEMA other than 'dbo' (not yet supported) ***"
[array]$usersNotOnDbo = $sourceUsers | Where-Object -Property DefaultSchema -notlike "dbo"
[array]$usersNotOnDbo = $usersNotOnDbo | Where-Object -Property DefaultSchema -notlike ""
if ($usersNotOnDbo.length -gt 0){
    $msg = "Found " + $usersNotOnDbo.length + " USERS with a DEFAULT SCHEMA other than 'dbo' in $usersFile. Please note, that DEFAULT SCHEMAS other than 'dbo' are not yet fully supported. You will need to set the DEFAULT SCHEMA for the following USER(S) manually for the time being: "
    foreach ($user in $usersNotOnDbo){
        $msg = $msg + $user.Name + ", "
    }
    Write-Error $msg 
    $errorCount += 1
    $errorTypes += " Found " + $usersNotOnDbo.length + " USERS with a DEFAULT SCHEMA other than 'dbo' in $usersFile."
}
else {
    Write-Output "All USERS in $usersFile that have DEFAULT SCHEMAS are on 'dbo'."
}

# Throwing error if $errorCount > 0 to ensure DeplpoySecurity.ps1 stops before deployment
if($errorCount -gt 0){
    $errorMsg =  "Failed pre-deployment checks with $errorCount error(s)!:"
    $errorMsg = $errorMsg + $errorTypes
    throw $errorMsg
}