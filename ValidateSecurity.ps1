param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Database,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SourceDir
)

# A script to verify that the security on a target database matches the source code.
Write-Output ""
Write-Output "***** VALIDATING $SQLInstance.$Database MATCHES SOURCE CODE AT $SourceDir FOR ENVIRONMENT $Environment *****"
Write-Output ""

Write-Output "Reading the users and role members from $SQLInstance.$Database."
[array]$rawDbUsers = Get-DbaDbUser -SqlInstance $SQLInstance -Database $Database -ExcludeSystemUser
[array]$rawDbRoleMembers = Get-DbaDbRoleMember -SqlInstance $SQLInstance -Database $Database

Write-Output "Reading the users and role members from $SourceDir."
$usersFile = Join-Path -Path $SourceDir -ChildPath "users.json"
[array]$sourceUsers = Get-Content $usersFile | ConvertFrom-Json
$roleMembersFile = Join-Path -Path $SourceDir -ChildPath "rolemembers_$Environment.json"
[array]$sourceRoleMembers = Get-Content $roleMembersFile | ConvertFrom-Json

$errors = 0

# Helper functions

function checkUser($username){
    $match = $true
    if ($sourceUsers.Name -contains $username){
        # There should be an identical user in $rawDbUsers
        $matchingSourceUser = $sourceUsers | Where-Object {$_.Name -like $username}
        $matchingDbUser = $rawDbUsers | Where-Object {$_.Name -like $username}

        # If there is no user with a matching username, fail the match
        if (!$matchingDbUser){
            $match -eq $false
            $errors += 1
            $warning = "USER $username does not exist on $SQLInstance.$Database."
            Write-Warning $warning
        }
        
        # If the matched user has a different Login, fail the match
        if ($matchingDbUser -and ($matchingSourceUser.Login -notLike $matchingDbUser.Login)){
            $match -eq $false
            $errors += 1
            $warning = "USER $username has LOGIN " + $matchingSourceUser.Logi0n + " in $usersFile but " + $matchingDbUser.Login + " on $SQLInstance.$Database."
            Write-Warning $warning
        }
    return $match
    }
}

function checkRoleMember($role){
    if ($sourceRoleMembers.Role -contains $role){
        [array]$matchingDbRoleMembers = $rawDbRoleMembers | Where-Object {$_.Role -like $role}       
        [array]$sourceRole = $sourceRoleMembers | Where-Object -Property Role -like $role  
        [array]$dbMembers = $matchingDbRoleMembers.UserName

        # There should be at least one matching role member in $rawDbRoleMembers
        if ($matchingDbRoleMembers.length -eq 0){
            $errors += 1
            $warning = "ROLE $role either does not exist or has no members on $SQLInstance.$Database."
            Write-Warning $warning
        }
        # The role should have the same members in both source and db
        elseif (Compare-Object $sourceRole.Members $dbMembers) {
            # Warning
            $warning = "ROLE $role has members in source and target but the values do not match!"
            Write-Warning $warning
            $errors += 1
            Write-Output "Source version on the left, DB version on the right. (Note this always appears at bottom of logs. Not sure why.):"
            Write-Output (Compare-Object $sourceRole.Members $dbMembers)
            
        }
    }
}


# Checking all the users in source exist on db
foreach ($user in $sourceUsers){
    if ($user.Environment -contains $Environment){
        checkuser($user.Name) | out-null
    }
}

foreach ($role in $sourceRoleMembers.Role){
    checkRoleMember($role)
}

# Checking that there are no users on DB that are missing from source
[array]$sourceUsersForEnvironment = $sourceUsers | Where-Object -Property Environment -contains $Environment
foreach ($user in $rawDbUsers){
    if ($user.Name -notin $sourceUsersForEnvironment.Name){
        $warning = "USER " + $user.Name + " exists on $SQLInstance.$Database but does not exist in $usersFile for environment $Environment"
        Write-Warning $warning
    }
}

# Checking that there are no role members on DB with roles that are missing from source
$uniqueDbRolesWithMembers = $rawDbRoleMembers.Role | Sort-Object -unique
foreach ($role in $uniqueDbRolesWithMembers){
    if ($role -notin $sourceRoleMembers.Role){
        $warning = "ROLE " + $role + " has members on $SQLInstance.$Database but does not exist in $roleMembersFile"
        Write-Warning $warning
    }
}


Write-Warning "Error handling at the end is broken. Always passes."
# Throwing error if $errorCount > 0 to ensure DeplpoySecurity.ps1 stops before deployment
if($errors -gt 0){
    $errorMsg =  "Failed security validation with $errorCount inconsistencies! (See warnings.)"
    throw $errorMsg
}
else {
    Write-Output "All users and roles members on $SQLInstance.$Database consistent with $SourceDir for environment $Environment "
}