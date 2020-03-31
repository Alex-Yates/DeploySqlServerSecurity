param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SourceDir,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment
)

Write-Warning "ToDo: Write some Pester tests"

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

$MajorPsVersion = $PSVersionTable.PSVersion.Major
$MinorPsVersion = $PSVersionTable.PSVersion.Minor
if(($MajorPsVersion -gt 6) -or (($MajorPsVersion -eq 6) -and ($MinorPsVersion -ge 1))){
    Write-Output " "
    Write-Output "*** CHECK: Do the source files contain valid syntax? ***"
    Write-Warning "To do: Verify the source files" 
    if ($roleMembersFile | Test-Json){
        Write-Output "$roleMembersFile contains valid JSON syntax." 
    }
    else {
        $msg = "$roleMembersFile does not contain valid JSON syntax. Please inspect file and correct errors."
        Write-Error $msg 
        $errorCount += 1
        $errorTypes += " $roleMembersFile incorrectly formatted."
    }
    if ($usersFile | Test-Json){
        Write-Output "$userFile contains valid JSON syntax.." 
    }
    else {
        $msg = "$usersFile does not contain valid JSON syntax. Please inspect file and correct errors."
        Write-Error $msg 
        $errorCount += 1
        $errorTypes += " $usersFile incorrectly formatted."  
    }
}
else {
    Write-Warning "Check for valid JSON syntax skipped because the cmdlet Test-Json required PowerShell v6.1 (This machine is only running PowerShell v$MajorPsVersion.$MinorPsVersion.)"
}

Write-Output "Reading data from source files."
$sourceUsers = Get-Content $usersFile | ConvertFrom-Json
$sourceRoleMembers = Get-Content $roleMembersFile | ConvertFrom-Json

# Throwing error if $errorCount > 0 to ensure DeplpoySecurity.ps1 stops before deployment
if($errorCount -gt 0){
    $errorMsg =  "Failed pre-deployment checks with $errorCount error(s)!:"
    $errorMsg = $errorMsg + $errorTypes
    throw $errorMsg
}