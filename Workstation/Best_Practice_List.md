# Configuration Enforcement
- Set HOSTS file to default
- Ensure "Auto Logon" is disabled: https://windowsreport.com/auto-login-windows-10/
- Only member in "Local Administrators" group is ".\local_dkbtech"
- DHCP DNS on NIC
- No services running as users
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
- All internal drives encrypted
- Protection enabled, not paused
- Encryption type is AES256
### Browser Control
- Block user extension installation
- Disable built in password managers
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
- Verify no missing drivers, attempt Windows driver update to remediate <br>
```Get-WmiObject Win32_PNPEntity -EA 0 | Where-Object{$_.Availability -eq 11 -or $_.Availability -eq 12}```
- Verify hardware devices in Error, Degraded, or Unknown states <br>
```Get-PnpDevice -PresentOnly -Status ERROR,DEGRADED,UNKNOWN -EA 0```


# Best Practice Checks
- Pro/Enterprise OS 
- More than 8GBs of RAM
- More than 4 logical cores
- No file shares
- No print shares
- Check to see if domain joined


# Monitoring
- Any services defined as installed and monitored via the service Powershell function
- Verify "UsoSvc" service (Update Orchestrator Service) is stopped and disabled
