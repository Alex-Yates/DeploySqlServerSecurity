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

$errorCount = 0

# Helper functions

function checkUser($username){
    if ($sourceUsers.Name -contains $username){
        # There should be a matching user in $rawDbUsers
        $matchingSourceUser = $sourceUsers | Where-Object {$_.Name -like $username}
        $matchingDbUser = $rawDbUsers | Where-Object {$_.Name -like $username}
        
        # If there is no user with a matching username, fail the match
        if (!$matchingDbUser){
            $warning = "USER $username does not exist on $SQLInstance.$Database."
            Write-Warning $warning
            $script:errorCount += 1
        }
        
        # If the matched user has a different Login, fail the match
        if ($matchingDbUser -and ($matchingSourceUser.Login -notLike $matchingDbUser.Login)){
            $warning = "USER $username has LOGIN " + $matchingSourceUser.Logi0n + " in $usersFile but " + $matchingDbUser.Login + " on $SQLInstance.$Database."
            Write-Warning $warning
            $script:errorCount += 1
        }
    }
}

function checkRoleMember($role){
    if ($sourceRoleMembers.Role -contains $role){
        [array]$matchingDbRoleMembers = $rawDbRoleMembers | Where-Object {$_.Role -like $role}       
        [array]$sourceRole = $sourceRoleMembers | Where-Object -Property Role -like $role  
        [array]$dbMembers = $matchingDbRoleMembers.UserName

        # There should be at least one matching role member in $rawDbRoleMembers
        if ($matchingDbRoleMembers.length -eq 0){
            $warning = "ROLE $role either does not exist or has no members on $SQLInstance.$Database."
            Write-Warning $warning
            $script:errorCount += 1
        }
        # The role should have the same members in both source and db
        elseif (Compare-Object $sourceRole.Members $dbMembers) {
            $warning = "ROLE $role has members in $roleMembersFile and in $SQLInstance.$Database but the members do not match!"
            Write-Warning $warning
            $script:errorCount += 1           
        }
    }
}


# Checking all the users in source exist on db
foreach ($user in $sourceUsers){
    if ($user.Environment -contains $Environment){
        checkuser($user.Name)
    }
}

#Checking that all roles in source exist in db
foreach ($role in $sourceRoleMembers.Role){
    checkRoleMember($role)
}

# Checking that there are no users on DB that are missing from source
[array]$sourceUsersForEnvironment = $sourceUsers | Where-Object -Property Environment -contains $Environment
foreach ($user in $rawDbUsers){
    if ($user.Name -notin $sourceUsersForEnvironment.Name){
        $warning = "USER " + $user.Name + " exists on $SQLInstance.$Database but does not exist in $usersFile for environment $Environment"
        Write-Warning $warning
        $errorCount += 1
    }
}

# Checking that there are no role members on DB with roles that are missing from source
$uniqueDbRolesWithMembers = $rawDbRoleMembers.Role | Sort-Object -unique
foreach ($role in $uniqueDbRolesWithMembers){
    if ($role -notin $sourceRoleMembers.Role){
        $warning = "ROLE " + $role + " has members on $SQLInstance.$Database but does not exist in $roleMembersFile"
        Write-Warning $warning
        $errorCount += 1
    }
}

# Throwing error if $errorCount > 0 to ensure DeplpoySecurity.ps1 throws an error
if($errorCount -gt 0){
    $errorMsg =  "Failed security validation with $errorCount inconsistencies! (See warnings above.)"
    throw $errorMsg
}
else {
    Write-Output "All users and roles members on $SQLInstance.$Database consistent with $SourceDir for environment $Environment "
}