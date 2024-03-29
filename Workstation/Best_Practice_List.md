# Workstation Configuration Enforcement

## Keys

Status

- Pass = `1`
- Fail = `2`
- Variance = `3`

Remediation

- Not Remediated = `0`
- Remediated = `1`

### Check HOSTS file

- **Path**: `$env:WINDOWS\System32\Drivers\etc\hosts`
- **Details**: None
- **Action**:
  - None
- **Output**:
  - If HOSTS file not modified
    - STATUS: `1`
    - REMEDIATED: `0`
  - If HOSTS file is modified
    - STATUS: `3`
    - REMEDIATED: `0`
    - [HOSTS FILE CONTENTS]

### Ensure "Auto Logon" is disabled

- **Path**: `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`
- **Name**: `DefaultPassword`
- **Type**: `REG_SZ`
- **Value**: N/A
- **Action**:
  - Delete the `DefaultPassword` REG_SZ key if exists
- **Output**:
  - If `DefaultPassword` REG_SZ key not present
    - STATUS: `1`
    - REMEDIATED: `0`
  - If `DefaultPassword` REG_SZ key deleted by script
    - STATUS: `1`
    - REMEDIATED: `1`
  - If `DefaultPassword` present and remediation is disabled for any reason (client specifies or any other)
    - STATUS: `2`
    - REMEDIATED: `0`
  
### Verify Local Admin membership

- **Local Admin Group Members**:
  - `wks_dkbtech` (domain)
  - `lcl_dkbtech` (local)
  - `[Hidden AutoElevate Account]` (local)
  - `[Local user accounts specified by client]` (local)
- **Action**:
  - Remove all users from the local admin group that are not defined in the list above
- **Output**:
  - If only user above exist in the local Administrators group
    - STATUS: `1`
    - REMEDIATED: `0`
  - If script removes all users successfully other than users above
    - STATUS: `1`
    - REMEDIATED: `1`
  - If users exist in the local Administrators group outside of this defined list for any reason
    - STATUS: 2
    - REMEDIATED: `0`

### DHCP DNS on all NICs

- **Desired State**:
  - All physical NICS connected (NICs with active connections) have DHCP enabled for both IP and DNS servers
- **Action**:
  - None
- **Output**:
  - If DHCP is enabled and being used for the IP and for DNS
    - STATUS: `1`
    - REMEDIATED: `0`
  - If DHCP is not being used for either the IP or DNS
    - STATUS: `3`
    - REMEDIATED: `0`
- **Helpful Code**:
  - Code to check the status of DHCP on all active NICs

  ```Powershell
  Get-NetAdapter | ? {$_.Status -eq "Up"} | Get-NetIPInterface -AddressFamily IPv4
  ```

  - Code to enable DHCP on all active NICs

  ```Powershell
  # Get all IPv4 network adapters that have an active connection. That means this ignores WiFI and/or physical 
  # NICs with no connection
  Get-NetAdapter | ? {$_.Status -eq "Up"} | Get-NetIPInterface -AddressFamily IPv4 | ForEach-Object {
    If ($_.Dhcp -eq "Enabled") {
      # Enable DHCP on the adapter in the current iteration
      $_ | Set-NetIPInterface -DHCP Enabled
      # After you set DHCP to enabled it will not grab an IP automatically so you need to tell it to do that
      ipconfig /release
      ipconfig /renew
    }
  }
  ```

### Block domains

- **Desired State**:
  - Verify we cannot hit pastebin.com
  - Verify we cannot hit bit.ly
- **Action**:
  - Add pastbin.com and bit.ly to the `HOSTS` file and point to local loopback 127.0.0.1
- **Output**:
  - If unable to ping pastebin.com and bit.ly and no action was taken from the script
    - STATUS: `1`
    - REMEDIATED: `0`
  - If unable to ping pastebin.com and bit.ly and the script performed actions to enforce this
    - STATUS: `1`
    - REMEDIATED: `1`
  - If able to ping either pastebin.com or bit.ly
    - STATUS: `2`
    - REMEDIATED: `0`

### Enable Windows Firewall

- **Desired State**:
  - Windows firewall enabled for all networks (Domain, Public, Private)
- **Action**:
  - Enable firewall on all networks if not already enabled
- **Output**:
  - If firewall is enabled on all 3 networks with no action from script
    - STATUS: `1`
    - REMEDIATED: `0`
  - If firewall was disabled then enabled by script
    - STATUS: `1`
    - REMEDIATED: `1`
  - If firewall is disabled and excluded from being enabled for any reason
    - STATUS: `2`
    - REMEDIATED: `0`
- **Helpful Code**:
  - Enable the firewall on all profiles

  ```Powershell
  Net-NetFirewallProfile -Profile Domain, Public, Private -Enabled True
  ```

  - Check the status of the firewall on all profiles

  ```Powershell
  Get-NetFirewallProfile
  ```

### Disable RDP

- **Desired State**:
  - RDP should be disabled for all workstations
- **Action**:
  - Disabled RDP if it is not already disabled
- **Output**:
  - If RDP is already disabled with no action taken
    - STATUS: `1`
    - REMEDIATED: `0`
  - If RDP was enabled and our script disables it
    - STATUS: `1`
    - REMEDIATED: `1`
  - If RDP is disabled and remediation is excluded for any reason
    - STATUS: `2`
    - REMEDIATED: `0`

### Audit Log Configuration

Note the output state here applies to the output for all of these registry entries. Since there's so much
data the format here is switched up slightly.

- **Desired State**:
  - For all registry values below to be the live production values for all endpoints
- **Action**:
  - Align the registry value to the stated values below in the Registry Values section
- **Output**:
  - If the registry key and value already exist as stated below
    - STATUS: `1`
    - REMEDIATED: `0`
  - If the registry key doesn't exist, or the value doesn't match, and the script remediated
    - STATUS: `1`
    - REMEDIATED: `1`
  - If the registy key doesn't exist, or the value doesn't match, and setting these to expected values is excluded for any reason
    - STATUS: `2`
    - REMEDIATED: `0`
- **Registry Values**
  - Max [Application] log configuration
    - **Path**: HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Application
    - **Name**: MaxSize
    - **Type**: REG_DWORD
    - **Value**: `102400`
  - Max [Security] log configuration
    - **Path**: HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security
    - **Name**: MaxSize
    - **Type**: REG_DWORD
    - **Value**: `102400`
  - Max [System] log configuration
    - **Path**: HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\System
    - **Name**: MaxSize
    - **Type**: REG_DWORD
    - **Value**: `102400`
  - Max [Setup] log configuration
    - **Path**: HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Setup
    - **Name**: MaxSize
    - **Type**: REG_DWORD
    - **Value**: `102400`
  - Prevent local guests group from accessing [Application] log
    - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application
    - **Name**: RestrictGuestAccess
    - **Type**: REG_DWORD
    - **Value**: `1`
  - Prevent local guests group from accessing [System] log
    - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\System
    - **Name**: RestrictGuestAccess
    - **Type**: REG_DWORD
    - **Value**: `1`
  - Prevent local guests group from accessing [Security] log
    - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Security
    - **Name**: RestrictGuestAccess
    - **Type**: REG_DWORD
    - **Value**: `1`
  - Retain [Application] log
    - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\Application
    - **Name**: AutoBackupLogFiles
    - **Type**: REG_DWORD
    - **Value**: `0`
  - Retain [Security] log
    - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\Security
    - **Name**: AutoBackupLogFiles
    - **Type**: REG_DWORD
    - **Value**: `0`
  - Retain [System] log
    - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\System
    - **Name**: AutoBackupLogFiles
    - **Type**: REG_DWORD
    - **Value**: `0`
  - Retention method for [Application] log
    - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\Application
    - **Name**: Retention
    - **Type**: REG_DWORD
    - **Value**: `0`
  - Retention method for [Security] log
    - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\Security
    - **Name**: Retention
    - **Type**: REG_DWORD
    - **Value**: `0`
  - Retention method for [System] log
    - **Path**: HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\System
    - **Name**: Retention
    - **Type**: REG_DWORD
    - **Value**: `0`
  - Windows [Powershell] Log Max Size
    - **Path**: HKLM:\SYSTEM\CurrentControlSet\services\eventlog\Windows PowerShell
    - **Name**: MaxSize
    - **Type**: REG_DWORD
    - **Value**: `1048576`
  - Windows [Powershell] Log Retention
    - **Path**: HKLM:\SYSTEM\CurrentControlSet\services\eventlog\Windows PowerShell
    - **Name**: Retention
    - **Type**: REG_DWORD
    - **Value**: `0`
  - [Microsoft-Windows-PowerShell/Operational] Log
    - **Path**: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-PowerShell/Operational
    - **Name**: Enabled
    - **Type**: REG_DWORD
    - **Value**: `1`
  - [Microsoft-Windows-PowerShell/Operational] Log Max Size
    - **Path**: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-PowerShell/Operational
    - **Name**: MaxSize
    - **Type**: REG_DWORD
    - **Value**: `1048576`
  - [Microsoft-Windows-PowerShell/Operational] Log Retention
    - **Path**: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-PowerShell/Operational
    - **Name**: Retention
    - **Type**: REG_DWORD
    - **Value**: `0`

### Microsoft Defender

- **Desired State**:
  - Protection enabled
  - Running in passive mode if S1 is installed
  - Disabled if OS does not support passive mode and S1 is installed
- **Action**:
  - Enable protection if disabled and S1 installed
  - Set to passive mode if not in passive mode and S1 is installed
- **Output**:
  - If Defender is enabled and running in passive mode with S1 installed
    - STATUS: `1`
    - REMEDIATED: `0`
  - If Defender was not enabled and in passive mode if S1 is installed, then the script corrected it to desired state
    - STATUS: `1`
    - REMEDIATED: `1`
  - If Defender is not enabled or not in passive mode for any reason and S1 is installed
    - STATUS: `2`
    - REMEDIATED: `0`
  - If S1 is not installed
    - STATUS: `3`
    - REMEDIATED: `0`
- **Helpful Code**:
  - This script was created to manually disable Defender in scenarios where the OS doesn't support Defender passive mode. I would also like to not assume that Defender is enabled and in passive mode (like this current script does) and instead verify it's enabled with code and then ensure it's in passive mode IF SentineLOne is installed.
  <https://github.com/dkbrookie/Software/blob/master/Microsoft/Windows_Defender/Manually_Disable.ps1>

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

  ```Powershell
  Get-WmiObject Win32_PNPEntity -EA 0 | Where-Object{$_.Availability -eq 11 -or $_.Availability -eq 12}
  ```

- Verify hardware devices in Error, Degraded, or Unknown states

  ```Powershell
  Get-PnpDevice -PresentOnly -Status ERROR,DEGRADED,UNKNOWN -EA 0
  ```

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
