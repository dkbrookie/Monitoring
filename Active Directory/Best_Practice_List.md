# AD Desired State

It would be nice to log the last "change" to the status if possible. So basically, if it was `STATUS:1` but then it was changed and went to `STATUS:2`, we should have the date it went to failed. That would highlight the date the setting was changed to take it out of alignment and could help us in logs.

## First thoughts of things to check

1) SYSVOL rep type is DFS-R
2) Time is synced between all servers
3) If Physical machine, time synced to external source
4) If Hyper-V VM, time synced to host. If vmware VM, time synced to external source
5) SYSVOL file replication regularly tested functional regularly
6) AD Recycling Bin enabled
7) Forest level matches lowest OS of all DCs
8) Shadowcopy is enabled
9) General replication tested functional regularly

## vCTO Section to replace their questions

As part of our desired state checks we're going to try and get rid of as many vCTO questions on their manual reviews as possible. As part of this, we need to output the data our scripts are checking, verifying, and/or fixing, and make a BG board where they can copy/paste the answer into their review. This way the questions remain, but the work (aside from copy/paste) is removed.

### Active Directory Organization

Are users and computer accounts in the correct OUs in Active Directory w/ no items in the default OUs?

If users or computer accounts are not in the correct OU's then they might not get the proper GPO's (policies) applied to them. Users may have incorrect permissions and unauthorized access if organized incorrectly.

Check default Computers OU for workstations/servers. Move workstations to the appropriate OUs in order for GPOs to apply. Proceed with caution moving servers to different OUs (especially if terminal servers). Make sure no users are in default Users OU. Move to most applicable OU (based on location, department, etc).If its found to be a result of a failed onboarding or workstation setup (SDI or PS) well do like we do with projects and push it back to the originating team to remediate.

#### Tasks

- [ ] Need to make a script to check for count of objects that are of the user or computer type in both the default users, and default computers OUs in AD. If maintained, these should be empty except for some default groups (which we're not concerned with at this time)

#### Helpful Code

```Powershell
Get-ADUser -Filter * -SearchBase “ou=testou,dc=iammred,dc=net”
```

#### Output

If the count of objects in both the default computers and default users OU is 0

- STATUS: `1`
- REMEDIATED `0`

If either the default computer or default users OU returns a count of more than 0

- STATUS: `2`
- REMEDIATED: `0`

### Domain Admin Rights

Verified that no end users, including IT users, are domain admins? List Domain Admin users in your answer

Potential for unauthorized folder/file access to sensitive data if granted.

Follow the SOP here: <https://dkbinnovative.itglue.com/1119054/docs/7773531Check> Domain Admin security group. Note that removing domain admin rights may affect users having local admin rights on their workstation. If admin rights are required then they need a separate account from their standard account for Domain Admin permissions.

### Complex local/domain admin password

Are complex passwords in place for local and domain administrators?

Prevents unauthorized access to domain (or workstation) level tasks; harder to crack if password is complex.

Verify what the password is and if its not at least 12+ characters with uppercase, lowercase, number and symbol requirements then it is not strong and complex enough.

### Local Admin Rights

Are Workstation and Server local administrative rights restricted to only DKB and Domain Administrators (are Domain Users excluded)?

It is less likely for a user to inadvertently cause operating system damage if they do not have the rights to install applications or change important system settings. This also greatly reduces the risk of malware and spyware infection and damage.

1.Verify there are no Local Administrator GPOs:GPOs are usually place on OU(s) where computers are stored. The patch to look for is: Computer Configuration Policies Windows Settings Security Settings Restricted Groups edit the Administrators groupThe AD group containing users who would be allowed local admin access is here. 2.You can also run the GetLocalAdminsGUI setup in CW Control tools: Tool URL <http://www.cjwdev.co.uk/Software/GetLocalAdminsGUI/Info.html>

#### Tasks

- [ ] Make the `Library.Users` script live to fulfill this review question vCTO is currently manually answering
- [ ] Output to BG dashboard that this is enforced via script, and AD check is no longer required
- [ ] Possibly output GPOs with local admin controls enabled so they can be disabled so there's no overlap? This could be accomplished with the GPO search script we already have located here: <https://github.com/dkbrookie/General-Powershell/blob/master/Domain%20Controllers/DC.FindGPO.ps1> by searching for `Local Administrators` (needs testing)

#### Helpful Code

```Powershell
## Get the string you want to search for
$string = Read-Host -Prompt "What string do you want to search for?"

## Set the domain to search for GPOs
$DomainName = $env:USERDNSDOMAIN

## Find all GPOs in the current domain
write-host "Finding all the GPOs in $DomainName"
Import-Module GroupPolicy
$allGposInDomain = Get-GPO -All -Domain $DomainName
## Look through each GPO's XML file for the string
Write-Host "Searching...."
ForEach ($gpo in $allGposInDomain) {
    $report = Get-GPOReport -Guid $gpo.Id -ReportType Xml
    If ($report -match $string) {
        # This doesn't actually need an out file, it was just made when I was greener to
        # storing results in vars
        $report | Out-File "c:\gpoOut.txt"
        $report = Get-Content "c:\gpoOut.txt"
        Write-Host "**************************************"
        Write-Host "** Match found in GPO"
        Write-Host "    $($gpo.DisplayName)"
        $valuePattern = "<q1:Value>(.*)</q1:Value>"
        $value = [regex]::match($report, $valuePattern).Groups[1].Value
        $linkPattern = "<SOMPath>(.*)</SOMPath>"
        $link = $report | Select-String -Pattern $linkPattern
        $link = $link -replace("<SOMPath>","") -replace ("</SOMPath>?","")
        Write-Host "** Current Linked OUs"
        ForEach($ou in $link) {
            $ou
        }
    Write-Host "**************************************"
    }
}

If((Test-Path C:\gpoOut.txt -PathType Leaf)) {
    Remove-Item -Path C:\gpoOut.txt -Force
}
```

#### Output

If the `Library.Users` script is enforced for the client and handling local admin users

- STATUS: `1`
- REMEDIATED `1`

If the `Library.Users` script is NOT enforced for the client

- STATUS: `2`
- REMEDIATED: `0`

### No Non-Expiring Passwords

Have you verified there are no user accounts set with non-expiring passwords? (Service accounts with non-interactive logon permission are an exception to this rule.)

High risk of an attacker cracking a user's password over time if password is not set to expire.

Follow the SOP here: <https://dkbinnovative.itglue.com/1119054/docs/7773531>

#### Code

```Powershell
# Import the AD module to the session
Import-Module ActiveDirectory

# Search for users w/ password never expires set to true
Get-Aduser -Filter * -Properties Name, PasswordNeverExpires | Where {
    # Can't remember if $_.Name is the right one...it may be like PrincipalName or similar
    $_.passwordNeverExpires -eq "true" -and $_.Name -notlike 'svc_*'
} |  Select-Object DistinguishedName,Name,Enabled
```

#### Tasks

- [ ] Test the above code on a Primary Domain Controller and verify the reuslts are accurate
- [ ] If service accounts are identified that are OK to be in place that are not prefaced witih `svc_` there may be scenarios where that's okay, so we may need a place to make an "exclusions" list for passord never expires accounts

### Complex Passwords

Are complex passwords enabled?

By enforcing strong passwords you increase the overall security of the whole network by decreasing the risk of successfully guessed or dictionary-based password hacks.

Verify the group policy settings (typically under Default Domain Policy) and verify this is configured in the Password Policy section.

### Password Age

Is the Maximum Password Age set to 90 Days or less?

Many policies require users and administrators to change their passwords periodically. In such cases, the frequency should be determined by the enforced length and complexity of the password, the sensitivity of the information protected, and the exposure level of passwords.

Verify the group policy settings (typically under Default Domain Policy) and verify this is configured in the Password Policy section.

### Minimum Password Age

Is the Minimum Password Age set to 1 days or more?

If not set, user can reset as many times as necessary to reuse original password. If an attacker is targeting a specific individual user account, with knowledge of data about that user, reuse of old passwords can cause security breach.

Verify the group policy settings (typically under Default Domain Policy) and verify this is configured in the Password Policy section.

### Account Lockout Duration

Are accounts setup to lockout for 15 minutes after x amount of attempts?

Business Impact: Online brute force password attacks can use automated methods to try millions of password combinations for any user account. The effectiveness of such attacks can be almost eliminated if you lockout the account for a period of time.

Verify the group policy settings (typically under Default Domain Policy) and verify this is configured in the Password Policy section.

### Account Lockout Threshold

Are accounts set to lock after 10 invalid attempts?

Online brute force password attacks can use automated methods to try millions of password combinations for any user account. The effectiveness of such attacks can be almost eliminated if you limit the number of failed logons that can be performed.

Verify the group policy settings (typically under Default Domain Policy) and verify this is configured in the Password Policy section.

### Reset Account Lockout counter

Is lockout counter set to reset after 15 minutes?

Resetting this after 15 minutes is sufficient to prevent an automated attack and allows locked out users to get back in without further service.

Verify the group policy settings (typically under Default Domain Policy) and verify this is configured in the Password Policy section.

### Enforce Password History

Is the policy set that prevents previous 24 passwords from being used on account?

Prevent users from using the same password multiple times to bypass requirements to change passwords.

Verify the group policy settings (typically under Default Domain Policy) and verify this is configured in the Password Policy section.

### Reversible Encryption Off

Is Store Password Using Reversible Encryption set to Off?

Reversible encryption may allow an attacker to determine passwords if they were to gain access to your Active Directory system. Setting this to "off" makes it extremely difficult to crack passwords. Storing passwords using reversible encryption is essentially the same as storing plain-text versions of the passwords. For this reason, this policy should never be enabled unless application requirements outweigh the need to protect password information.

Verify the group policy settings (typically under Default Domain Policy) and verify this is configured in the Password Policy section.

### Mapped Drives

Are group policies in place to map drives for users based on pre-defined criteria (i.e. department, role, etc.)?

Encourages uniformity across network; less time spent manually mapping drives for user if user logs into another workstation

Check Group Policy Management Console (installed on domain controllers). If mapped drives are created (make sure name is clear at reflecting this), verify they are on correct OU(s). Make sure AD profiles aren't running a logon batch file that maps drives (common with some newer clients).

### Login Auditing

Are successful and failed logons configured to be audited in event logs?

Can help to trace potential security breaches (i.e. random password hacking attempts, stolen password break-in's, etc.) with timestamps. By default, Windows monitors successful logins, not failures, on workstations.

This will be in a group policy (Computer Configuration Policies Windows Settings Security Settings Local Policies/Audit Policy. Audit logon events should have success and failure enabled). Best practice is to break this out into its own policy (named Monitor Logon Failures) if its inside of the Default Domain Policy for a clear reference.

### Inactive User Accounts

User accounts not used in the last 90 days have been disabled?

Disabling inactive accounts regularly prevents ex-employees from attempting to access the network.

Follow the SOP here: <https://dkbinnovative.itglue.com/1119054/docs/7773531>

### AD Recycle Bin

Is AD Recycle Bin enabled on domain controllers?

Enabling AD recycle Bin allows you to restore users that have been disabled.

This can be done via the GUI or powershell, <https://blog.technotesdesk.com/how-to-enable-active-directory-recycle-bin-in-server-2012-r2https://activedirectorypro.com/enable-active-directory-recycle-bin-server-2016/>
