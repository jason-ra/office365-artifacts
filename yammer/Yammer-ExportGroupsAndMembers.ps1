# PowerShell script to export Yammer groups, members and admins
# Token hint: https://support.office.com/en-us/article/export-yammer-group-members-to-a-csv-file-201a78fd-67b8-42c3-9247-79e79f92b535#step2
# Token hint2: https://www.yammer.com/client_applications
# Pre-requisite: Enable Private Content Mode so the export includes private groups you're not a member of
# Remember to clean up token & revert Content Mode when complete

# Set variables
$Token = "" #paste token here
 
$Headers = @{
 "Authorization" = "Bearer "+$Token
}

# Get a list of Yammer groups. Calls in pages as each search is limited to 50 results
$GroupCycle = 1
DO {
    $GetMoreGroupsUri = "https://www.yammer.com/api/v1/groups.json?page=$GroupCycle"
    write-host ($GetMoreGroupsUri)
    $MoreYammerGroups = (Invoke-WebRequest -Uri $GetMoreGroupsUri -Method Get -Headers $Headers).content | ConvertFrom-Json 
    $YammerGroups += $MoreYammerGroups
    $GroupCycle ++
    $GroupCount = $YammerGroups.Count
} 
While ($MoreYammerGroups.Count -gt 0)

$YammerGroups | Export-Csv group-export.csv -NoTypeInformation
$YammerGroups | select type,id,full_name,privacy,created_at

# For each group, list the members and the admins. Calls in pages as each search is limited to 50 results
$GroupAdmins = @()
$GroupMembers = @()
$GroupSummary = @()
$GroupCount = 0
foreach ($group in $YammerGroups) {
    $GroupId = $group.id
    [string]$GroupCreatedAt = $group.created_at
    $GroupCycle = 1
    DO {
        if ($GroupCycle -eq 1) { $AdminCount = 0; $GroupCount = 0 }
        $GetGroupMembersUri = "https://www.yammer.com/api/v1/groups/$GroupId/members.json?page=$GroupCycle"
		write-host ("REST API CALL : $GetGroupMembersUri")
        $MoreGroupMembers = ((Invoke-WebRequest -Uri $GetGroupMembersUri -Method Get -Headers $Headers).content | ConvertFrom-Json).users | select @{N='group_id';E={$group.id}},@{N='group_name';E={$group.full_name}}, @{N='group_privacy';E={$group.privacy}}, @{N='group_show_in_directory';E={$group.show_in_directory}}, @{N='group_created_at';E={$GroupCreatedAt}}, type, @{N='user_id';E={$_.id}}, full_name, email, state, is_group_admin
        foreach ($member in $MoreGroupMembers) {
            if ($member.is_group_admin -eq "True") {
                $GroupAdmins += $member
                $AdminCount ++
            }
            $GroupMembers += $member
            $GroupCount ++
        }
        $GroupCycle ++
    }	
	While ($MoreGroupMembers.count -gt 0)
    $groupResult = @{
        Group_Name = $group.full_name
        ID = $group.id
        State = $group.state
        Privacy = $group.privacy
        Show_In_Directory = $group.show_in_directory
        Created = $group.created_at
        Member_Count = $GroupCount
        Admin_Count = $AdminCount
    }
    $groupObject = New-Object -TypeName PSObject -Property $groupResult
    $groupSummary += $groupObject
    #$groupSummary += $groupResult
    write-output $groupObject
}

# Export the results to CSV files
$groupSummary | Select Group_Name, ID, State, Privacy, Show_In_Directory, Created, Member_Count, Admin_Count | export-csv group-summary.csv -NoTypeInformation
$groupAdmins | export-csv group-admin-export.csv -NoTypeInformation
$groupMembers | export-csv group-member-export.csv -NoTypeInformation
