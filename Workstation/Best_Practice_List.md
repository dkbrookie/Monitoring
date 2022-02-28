# Workstation Configuration Enforcement

## General Configuration

- Set HOSTS file to default
  - **Path**: $env:WINDOWS\System32\Drivers\etc\hosts
- Ensure "Auto Logon" is disabled. If the following REG_SZ exists, delete it
  - **Path**: HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon
  - **Name**: DefaultPassword
  - **Type**: REG_SZ
  - **Value**: N/A
- Only member in "Local Administrators" group is ".\local_dkbtech"
- DHCP DNS on all NICs
  - Mechanism to exclude machine if required, but enforced by default
- Verify we cannot hit pastebin.com
- Verify we cannot hit bit.ly
- Enable Windows firewall on all profiles

### Audit Log Configuration
- Max `Application` log configuration
  - **Path**: HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Application
  - **Name**: MaxSize
  - **Type**: REG_DWORD
  - **Value**: 102400
- Max `Security` log configuration
  - **Path**: HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security
  - **Name**: MaxSize
  - **Type**: REG_DWORD
  - **Value**: 102400
- Max `System` log configuration
  - **Path**: HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\System
  - **Name**: MaxSize
  - **Type**: REG_DWORD
  - **Value**: 102400
- Max `Setup` log configuration
  - **Path**: HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Setup
  - **Name**: MaxSize
  - **Type**: REG_DWORD
  - **Value**: 102400
- Prevent local guests group from accessing `Application` log
  - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application
  - **Name**: RestrictGuestAccess
  - **Type**: REG_DWORD
  - **Value**: 1
- Prevent local guests group from accessing `System` log
  - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\System
  - **Name**: RestrictGuestAccess
  - **Type**: REG_DWORD
  - **Value**: 1
- Prevent local guests group from accessing `Security` log
  - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Security
  - **Name**: RestrictGuestAccess
  - **Type**: REG_DWORD
  - **Value**: 1
- Retain `Application` log
  - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\Application
  - **Name**: AutoBackupLogFiles
  - **Type**: REG_DWORD
  - **Value**: 0
- Retain `Security` log
  - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\Security
  - **Name**: AutoBackupLogFiles
  - **Type**: REG_DWORD
  - **Value**: 0
- Retain `System` log
  - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\System
  - **Name**: AutoBackupLogFiles
  - **Type**: REG_DWORD
  - **Value**: 0
- Retention method for `Application` log
  - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\Application
  - **Name**: Retention
  - **Type**: REG_DWORD
  - **Value**: 0
- Retention method for `Security` log
  - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\Security
  - **Name**: Retention
  - **Type**: REG_DWORD
  - **Value**: 0
- Retention method for `System` log
  - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\System
  - **Name**: Retention
  - **Type**: REG_DWORD
  - **Value**: 0
- Windows `Powershell` Log Max Size
  - **Path**: HKLM:\SYSTEM\CurrentControlSet\services\eventlog\Windows PowerShell
  - **Name**: MaxSize
  - **Type**: REG_DWORD
  - **Value**: 1048576
- Windows `Powershell` Log Retention
  - **Path**: HKLM:\SYSTEM\CurrentControlSet\services\eventlog\Windows PowerShell
  - **Name**: Retention
  - **Type**: REG_DWORD
  - **Value**: 0
- `Microsoft-Windows-PowerShell/Operational` Log
  - **Path**: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-PowerShell/Operational
  - **Name**: Enabled
  - **Type**: REG_DWORD
  - **Value**: 1
- `Microsoft-Windows-PowerShell/Operational` Log Max Size
  - **Path**: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-PowerShell/Operational
  - **Name**: MaxSize
  - **Type**: REG_DWORD
  - **Value**: 1048576
- `Microsoft-Windows-PowerShell/Operational` Log Retention
  - **Path**: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-PowerShell/Operational
  - **Name**: Retention
  - **Type**: REG_DWORD
  - **Value**: 0
 

### Microsoft Defender

- Enabled
- Definitions fully updated from Windows Update (none pending install)
- Running in passive mode

### SentinelOne

- Installed
- Running current version defined by Github
- DKB policy enabled in Protect mode

### Bitlocker

- All internal drives are encrypted
  - <https://github.com/dkbrookie/Bitlocker/blob/master/Powershell/Bitlocker.encryptAllDrives.ps1>
  - <https://github.com/dkbrookie/Bitlocker/blob/master/Powershell/Bitlocker.decryptAllDrives.ps1>
- Protection enabled, not paused
  - <https://github.com/dkbrookie/Bitlocker/blob/master/Powershell/Bitlocker.unpauseProtection.ps1>
- Encryption type is AES256
  - <https://github.com/dkbrookie/Bitlocker/blob/master/Powershell/Bitlocker.getInfo.ps1>
- Encryption key is gathered and documented
  - <https://github.com/dkbrookie/Bitlocker/blob/master/Powershell/Bitlocker.getInfo.ps1>

### Browser Control

- Block user extension installation for Chrome, Firefox, and Edge
  - <https://chromeenterprise.google/policies/#ExtensionInstallBlocklist>.
    >"A blocklist value of '*' means all extensions are blocked unless they are explicitly listed in the allowlist"
  - Note the path for Chrome is `Software\Policies\Google\Chrome\ExtensionInstallBlocklist` so to adapt to Edge is only changing `Google\Chrome` to `Microsoft\Edge`
  - Note in this scenario you need to make a REG_SZ value inside of that registry key location named '1' (no quotes) and the value will be literally '*' (no quotes)
- Disable built in password managers for Chrome, Firefox, and Edge
  - <https://chromeenterprise.google/policies/?policy=PasswordManagerEnabled>
  >"false = Disable saving passwords using the password manager"
  In windows reg, the value of 0 is disabled.
  - Note the path for Chrome is `Software\Policies\Google\Chrome\ExtensionInstallBlocklist` so to adapt to Edge is only changing `Google\Chrome` to `Microsoft\Edge`
- Enforce browser restart after update for Chrome and Edge
  - <https://github.com/dkbrookie/Software/blob/master/Google/Chrome/Policies/Install_Google_Chrome_-_Relaunch_Enforcement.ps1>
  - <https://github.com/dkbrookie/Software/blob/master/Google/Chrome/Policies/Remove_Google_Chrome_-_Relaunch_Enforcement.ps1>

### Machine Policy

- Lockout screen after 15 min of inactivity w/ adjustadble time limit
- Disable fast user switching
- Hide last user logged in username at logon screen
- Logon Banner w/ adjustadble "Title" and "Body"

### Patching

- Proper Windows build number defined by Github
- Stopped/Disabled "UsoSvc" service (Update Orchestrator Service)
- Hidden Windows Updates
  - **Path**: HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer
  - **Name**: SettingsPageVisibility
  - **Type**: REG_SZ
  - **Value**: hide:windowsupdate
- Max Powershell version per OS

### Hardware

- Verify no missing drivers, attempt Windows driver update to remediate
  - ```Get-WmiObject Win32_PNPEntity -EA 0 | Where-Object{$_.Availability -eq 11 -or $_.Availability -eq 12}```
- Verify hardware devices in Error, Degraded, or Unknown states
  - ```Get-PnpDevice -PresentOnly -Status ERROR,DEGRADED,UNKNOWN -EA 0```

## Best Practice Checks

- Pro/Enterprise OS
- More than 8GBs of RAM
- More than 4 logical cores
- No file shares
- No print shares
- Check to see if domain joined
- No services running as users
  - Mechanism to exclude machine if required, but marks as out of alignment by default
- 10GBs of free space available on hard drive

## Monitoring

- Any services defined as installed and monitored via the service Powershell function
- Verify "UsoSvc" service (Update Orchestrator Service) is stopped and disabled
- Must have 10GBs of free space on primary Windows disk

## Maintenance

- Disk cleanup once weekly
- Disk defrag if disk is more than 15% fragemented
  - Disk must be spindle, not an SSD/NVMe
  - Only start defrag after 10PM or inside of maintenance window

## Low Priority Wish List
- Verify we cannot launch IP scanners
  - Don't think we can implement this since we use it for techs so often...so need a way to either block it to specific users, or to alert when it's used.