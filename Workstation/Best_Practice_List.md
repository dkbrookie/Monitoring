# Workstation Configuration Enforcement

## General Configuration

- Set HOSTS file to default
  - ```$env:WINDOWS\System32\Drivers\etc\hosts```
- Ensure "Auto Logon" is disabled
  - <https://windowsreport.com/auto-login-windows-10/>
- Only member in "Local Administrators" group is ".\local_dkbtech"
- DHCP DNS on all NICs
  - Mechanism to exclude machine if required, but enforced by default
- Verify we cannot hit pastebin.com
- Verify we cannot launch IP scanners
- Verify we cannot hit bit.ly
- Enable Windows firewall on all profiles

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
- Disable built in password managers for Chrome, Firefox, and Edge
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
- Hidden Windows Updates: 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer', "SettingsPageVisibility" REG_SZ with a value of "hide:windowsupdate"
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
