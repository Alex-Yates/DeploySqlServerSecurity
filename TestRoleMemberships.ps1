import-module dbatools

$Environment = "PROD"
$outPath = "C:\DeleteMe\RoleMemberships.json"
$rawRoleMembers = Get-DbaDbRoleMember -SqlInstance localhost -Database DbName

$dbRoleMembers = @()
if (Test-Path -path $outPath){
    $dbRoleMembers = Get-Content $outPath | ConvertFrom-Json
}

foreach ($role in $rawRoleMembers){    
    # If the role is not yet added to dbRoleMembers, add it.
    if ($dbRoleMembers.Name -notcontains $role.Role){
        $tempRole = New-Object PSObject -Property @{
            Name = $role.Role
            $Environment = @()
        }
        $dbRoleMembers = $dbRoleMembers + $tempRole
    }

    # If the role already exists, but the environment members list does not, add it
    $IdMatch = [array]::IndexOf($dbRoleMembers.Name,$role.Role)
    if (-not ($dbRoleMembers[$IdMatch] | Get-Member $Environment)){
        Add-Member -InputObject $dbRoleMembers[$IdMatch] -MemberType NoteProperty -Name $Environment -Value @()
    }

    # Add the role member to the environment list, if it does not already exist
    if ($dbRoleMembers[$IdMatch].$Environment -notcontains $role.UserName){
        $dbRoleMembers[$IdMatch].$Environment = $dbRoleMembers[$IdMatch].$Environment + $role.UserName
    }

    # Sorting members alphabetically
    $dbRoleMembers[$IdMatch].$Environment = $dbRoleMembers[$IdMatch].$Environment | Sort-Object
}

Write-Host "Total roles: " $dbRoleMembers.length

$dbRoleMembers = $dbRoleMembers | Sort-Object -Property Name
$dbRoleMembers = $dbRoleMembers | ConvertTo-Json

$dbRoleMembers | Out-File -FilePath $outPath