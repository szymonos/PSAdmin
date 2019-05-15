## Group Members ##
# Find groups
$groupsMultiDomains = '*service*'; foreach ($gdomain in 'domain1', 'domain2') { Get-ADGroup -Server $gdomain -Filter { Name -like $groupsMultiDomains -or Mail -like $groupsMultiDomains -or SamAccountName -like $groupsMultiDomains } -Properties Description, Mail | Sort-Object GroupCategory, SamAccountName | Format-List GroupCategory, @{name = 'DomainAccount'; expression = { $gdomain + '\' + $_.SamAccountName } }, SamAccountName, Name, Mail, Description }
$groups = '*service*'; Get-ADGroup -Filter { Name -like $groups -or Mail -like $groups -or SamAccountName -like $groups } -Properties Description, Mail | Sort-Object GroupCategory, SamAccountName | Format-List GroupCategory, @{name = 'DomainAccount'; expression = { 'ABCDATA\' + $_.SamAccountName } }, SamAccountName, Name, Mail, Description

# Get group members
$gMembersRecursive = 'ServiceDesk'; $ErrorActionPreference = 'SilentlyContinue'; foreach ($udomain in 'domain1', 'domain2') { Get-ADGroupMember -Server $udomain $gMembersRecursive -Recursive | Get-ADUser -Properties LastLogonDate, LockedOut | Sort-Object Name | Format-Table -AutoSize ObjectClass, UserPrincipalName, SamAccountName, Name, Enabled, LastLogonDate, LockedOut}
$gMembersMultiDomains = 'ServiceDesk'; $ErrorActionPreference = 'SilentlyContinue'; foreach ($udomain in 'domain1', 'domain2') { Get-ADGroupMember -Server $udomain $gMembersMultiDomains | Sort-Object Name | Get-ADUser -Properties LastLogonDate, LockedOut | Format-Table -AutoSize ObjectClass, UserPrincipalName, SamAccountName, Name, Enabled, LastLogonDate, LockedOut }
$gMembers = 'ServiceDesk'; $ErrorActionPreference = 'SilentlyContinue'; Get-ADGroupMember $gMembers | Sort-Object Name | Get-ADUser -Properties LastLogonDate, LockedOut | Format-Table -AutoSize ObjectClass, UserPrincipalName, SamAccountName, Name, Enabled, LastLogonDate, LockedOut
$gMembersConcat = 'ServiceDesk'; $ErrorActionPreference = 'SilentlyContinue'; $membersc = ''; foreach ($udomain in 'domain1', 'domain2') { Get-ADGroupMember -Server $udomain $gMembersConcat | Sort-Object Name | ForEach-Object { $membersc += ', ' + $_.Name } }; Write-Output $membersc.Substring(2)

# Find user identity
$userMultiDomains = '*szymon*'; foreach ($udomain in 'domain1', 'domain2') { Get-ADUser -Server $udomain -Filter { Name -like $userMultiDomains -or SamAccountName -like $userMultiDomains } -Properties Description, LockedOut, Office, Title, LastLogonDate | Format-Table -AutoSize @{name = 'DomainAccount'; expression = { $udomain + '\' + $_.SamAccountName } }, SamAccountName, Name, Title, Description, Enabled, LastLogonDate, LockedOut }
$user = '*szymon*'; Get-ADUser -Filter { Name -like $user -or SamAccountName -like $user } -Properties Description, LockedOut, Office, Title, LastLogonDate | Format-Table -AutoSize @{name = 'DomainAccount'; expression = { 'ABCDATA\' + $_.SamAccountName } }, SamAccountName, Name, Title, Office, Enabled, LastLogonDate, LockedOut
# Get user group membership
$uMemberOfAbcExt = 'szymono'; $ErrorActionPreference = 'SilentlyContinue'; foreach ($udomain in 'domain1', 'domain2') { foreach ($gdomain in 'domain1', 'domain2') { (Get-ADUser -Server $udomain -Identity $uMemberOfAbcExt –Properties MemberOf).MemberOf | Get-ADGroup -Server $gdomain -Properties Description | Sort-Object GroupCategory, SamAccountName | Format-Table -AutoSize GroupCategory, @{name = 'DomainAccount'; expression = { $gdomain + '\' + $_.SamAccountName } }, SamAccountName, Description }}
$uMemberOfAbc = 'szymono'; $ErrorActionPreference = 'SilentlyContinue'; (Get-ADUser -Identity $uMemberOfAbc –Properties MemberOf).MemberOf | Get-ADGroup -Properties Description | Sort-Object GroupCategory, SamAccountName | Format-Table -AutoSize GroupCategory, @{name = 'DomainAccount'; expression = { 'ABCDATA\' + $_.SamAccountName } }, SamAccountName, Description

# Check LockedOut accounts
foreach ($udomain in 'domain1', 'domain2') { Search-ADAccount -Server $udomain –LockedOut | Where-Object { $_.Enabled -eq 'True' } | Format-Table -AutoSize -Property @{name = 'DomainAccount'; expression = { $udomain + '\' + $_.SamAccountName } }, Name, LastLogonDate, PasswordExpired}

# Check all OU in domain
Get-ADOrganizationalUnit -Server 'domain' -Filter 'Name -like "*"' | Sort-Object -Property Name | Format-Table -AutoSize Name, DistinguishedName
# Check top OUs in ABCDATA and ABCEXT domains
Get-ADOrganizationalUnit -Server 'domain' -Filter 'Name -like "*"' -SearchScope OneLevel | Sort-Object -Property Name | Format-Table -AutoSize Name, DistinguishedName

# List of accounts that have not logged on since a specified in $check variable number of days and are disabled;
[int]$check = 180;Get-ADUser -Filter {Enabled -eq $False -and LastLogonDate -ne "*"} -Properties Name,SamAccountName,LastLogonDate | Where-Object {$_.lastLogonDate -ge [DateTime]::Now.AddDays(-$check)} | Sort-Object Name | Format-Table -AutoSize Name,SamAccountName,LastLogonDate

# check password expiry date
$userExpiry = 'szymono'; Get-ADUser -Server 'domain' -Filter { Name -like $userExpiry -or SamAccountName -like $userExpiry } -Properties 'DisplayName', 'msDS-UserPasswordExpiryTimeComputed' | Format-Table -AutoSize SamAccountName, Name, Enabled, @{Name = "ExpiryDate"; Expression = { [datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed") } }
