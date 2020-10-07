###############################################
## Check for DHCP lease remaining percentage ##
###############################################
<#
.Description
If the DHCP server runs out of available leases, the server will no longer be able to serve new
DHCP addresses, which means all DHCP devices looking for a new address will fail to connect to 
the network.
#>
$dhcpStatistics = Get-DhcpServerv4Statistics
If ($dhcpStatistics.PercentageAvailable -lt 5) {
    $dhcpLeaseStatus = 'Failed'
    $logOutput += "Your DHCP pool has under 5% total remaining leases to hand out.`r`n"
    $logOutput += "DHCP Addresses In Use: $($dhcpStatistics.AddressesInUse), DHCP Addresses Available: $($dhcpStatistics.AddressesAvailable)`r`n"
} Else {
    $dhcpLeaseStatus = 'Success'
    $logOutput += "Confirmed DHCP has sufficient available leases.`r`n"
    $logOutput += "DHCP Addresses In Use: $($dhcpStatistics.AddressesInUse), DHCP Addresses Available: $($dhcpStatistics.AddressesAvailable)`r`n"
}


#######################################
## Check for DHCP Conflict Detection ##
#######################################
<#
.Description
If conflict detection is not enabled, the DHCP server can lease out an IP address that is already 
is in use by another device. When conflict detection is enabled, the DHCP Server will ping the 
IP address in question before it leases out the IP address to another requesting a client device. 
If the DHCP server receives a reply from the ping, it will mark the IP address as BAD_ADDRESS and 
will not lease out.
#>
$dhcpSettings = Get-DhcpServerSetting
If ($dhcpSettings.ConflictDetectionAttempts -eq 0) {
    $conflictDetectionStatus = 'Failed'
    $logOutput += "Found DHCP conflict detection is currently disabled.`r`n"
} Else {
    $conflictDetectionStatus = 'Success'
    $logOutput += "Confirmed DHCP conflict deteciton is enabled!`r`n"
}

If ($dhcpLeaseStatus -eq 'Failed') {
    $fixLog += "DHCP Available Leases >5%: This means the DHCP server is running out of available leases. You should check your DHCP lease settings, and you may need to increase the DHCP scope.`r`n"
}
If ($conflictDetectionStatus -eq 'Failed') {
    $fixLog += "DHCP Conflict Detection Disabled: The recommendation is to enable DHCP Conflict Detection. When conflict detection is enabled, the DHCP Server will ping the IP address in question before it leases out the IP address to another requesting a client device. If the DHCP server receives a reply from the ping, it will mark the IP address as BAD_ADDRESS and will not lease out.`r`n"
}

"errors=$errorsOut|dhcpLeaseStatus=$dhcpLeaseStatus|conflictDetectionStatus=$conflictDetectionStatus|logOutput=$logOutput|fixLog=$fixLog"