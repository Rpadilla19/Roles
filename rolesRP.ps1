#script is meant to be ran using a raspberrypi
import-module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Users

$ApplicationId = <ApplicationId>
$SecuredPassword = <SecuredPassword>
$tenantID = <tenantID>

$SecuredPasswordPassword = ConvertTo-SecureString -String $SecuredPassword -AsPlainText -Force

$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationId, $SecuredPasswordPassword

Connect-MgGraph -ClientSecretCredential $ClientSecretCredential -TenantId $tenantID  -NoWelcome

Import-Module Microsoft.Graph.Identity.DirectoryManagement

$roles = Get-MgDirectoryRole | Select-Object DisplayName, Id
#$roles | Export-Csv -Path "RoleDir.csv" -NoTypeInformation

$roleMembers = @()
$groupId = @()
# Prints Roles and their members
foreach ($role in $roles) {
    $dirName = $role.DisplayName
    $dirId = $role.Id

    try {
        $members = Get-MgDirectoryRoleMember -DirectoryRoleId $dirId | Select-Object Id
        foreach ($member in $members) {
            $upn = Get-MgUser -UserId $member.Id -ErrorAction SilentlyContinue | Select-Object -ExpandProperty UserPrincipalName
            if ($upn) {
                $roleMembers += [PSCustomObject]@{
                    RoleName = $dirName
                    UserId = $member.Id
                    UserPrincipalName = $upn
                }
            } else {
                try {
                    $groupId += $member.Id
                    $groupDisplayName = Get-MgGroup -GroupId $member.Id -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisplayName

                    if ($groupDisplayName) {
                        $roleMembers += [PSCustomObject]@{
                            RoleName = $dirName
                            UserId = $member.Id
                            UserPrincipalName = "Group: $groupDisplayName"
                        }
                    } else {
                        $roleMembers += [PSCustomObject]@{
                            RoleName = $dirName
                            UserId = $member.Id
                            UserPrincipalName = "User/Group not found"
                        }
                    }
                }
                catch {
                    $roleMembers += [PSCustomObject]@{
                        RoleName = $dirName
                        UserId = $member.Id
                        UserPrincipalName = "User/Group not found"
                    }
                }
            }
        }
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)"
    }
}

#hashtables to verify uniqueness
$groupI = @{}
$groupDisName = @{}

#arrays
$groupI_A = @()
$groupdN_A = @()


foreach($group in $groupId) {
    $groupId = get-mggroup -GroupId $group | Select-Object -ExpandProperty Id

    if (-not $groupI.ContainsKey($groupId)) {
        $groupI[$groupId] = $null
    }

    $groupDN = get-mggroup -GroupId $group | Select-Object -ExpandProperty DisplayName

    if (-not $groupDisName.ContainsKey($groupDN)) {
        $groupDisName[$groupDN] = $null
    }
}


#created arrays to store hashtable outcome
$groupI_A += $groupI.Keys
$groupdN_A += $groupDisName.Keys

$Gresult = @()

foreach ($id in $groupI_A) {
    $Gname = get-mggroup -GroupId $id | Select-Object -ExpandProperty DisplayName

    $Gmember = @()

    $Gmember += Get-MgGroupMember -GroupId $id | Select-Object Id

    foreach ($member in $Gmember) {
        $user = Get-MgUser -UserId $member.Id | Select-Object UserPrincipalName, Id
        $Gfinal = [PSCustomObject]@{
        Group = $Gname
        ID = $id
        UPN = $user.UserPrincipalName
        UID = $user.Id
    }
    $Gresult += $Gfinal

    }

}

$Gresult | Export-Csv -path "Groups.csv" -NoTypeInformation
# Export the role members to a CSV file
$roleMembers | Export-Csv -Path "RoleMembers.csv" -NoTypeInformation
