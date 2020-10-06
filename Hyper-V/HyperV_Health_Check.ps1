Clear-Host

## Constants
$runningVMs = Get-VM | Where-Object { $_.State -eq 'Running' }
$allVMs = Get-VM


################################################
## Check Hyper-V integration service versions ##
################################################
<#
.Description
Monitoring Integration services on older version of hyper-v, or migrated versions is quite important 
as the hyper-v integration services also provider driver interfaces to the client VM’s
#>
$VMMS = Get-WmiObject -namespace root\virtualization\v2 Msvm_VirtualSystemManagementService

## 1 == VM friendly name. 123 == Integration State
$RequestedSummaryInformationArray = 1,123
$vmSummaryInformationArray = $VMMS.GetSummaryInformation($null, $RequestedSummaryInformationArray).SummaryInformation

$outputArray = @()
ForEach ($vmSummaryInformation in [array] $vmSummaryInformationArray) {  
    Switch ($vmSummaryInformation.IntegrationServicesVersionState) {
        1 {$vmIntegrationServicesVersionState = 'Up-to-date'}
        2 {$vmIntegrationServicesVersionState = 'Version Mismatch'}
        Default {$vmIntegrationServicesVersionState = 'Unknown'}
    }

    $vmIntegrationServicesVersion = (get-vm $vmSummaryInformation.ElementName).IntegrationServicesVersion
    If (!$vmIntegrationServicesVersion) {
        $vmIntegrationServicesVersion = 'Unknown'
    }

    $output = new-object psobject
    $output | add-member noteproperty "VM Name" $vmSummaryInformation.ElementName
    $output | add-member noteproperty "Integration Services Version" $vmIntegrationServicesVersion
    $output | add-member noteproperty "Integration Services State" $vmIntegrationServicesVersionState

    # Add the PSObject to the output Array
    $outputArray += $output
}

ForEach ($VM in $outputArray) {
    If ($VM.'Integration Services State' -contains "Version Mismatch") {
        $isDetails += "$($VM.'VM Name') Integration Services state is: $($VM.'Integration Services State')`r`n"
        $isStatus = 'Failed'
    }
}
If (!$isDetails) {
    $isDetails = 'Healthy'
    $isStatus = 'Success'
}


#########################
## Check NUMA Spanning ##
#########################
<#
.Description
You might notice a decrease in performance when your NUMA spanning incorrect, not just in assigned memory but 
a general performance degradation of up to 80%. Check these links for more details: 
https://www.itprotoday.com/server-virtualization/how-numa-spanning-affects-hyper-v-memory-allocation
https://docs.pexip.com/server_design/hyperv_numa_affinity.htm
#>
ForEach ($vm in $runningVMs) {
    $getvCPUCount = Get-VM -Name $vm.Name | Select-Object Name,NumaAligned,ProcessorCount,NumaNodesCount,NumaSocketCount
    $cpu = Get-WmiObject Win32_Processor
    $totalCPU = $cpu.numberoflogicalprocessors[0]*$cpu.count
    If ($getvCPUCount.numaAligned -eq $False) {
        $vcpuDetails += "NUMA not aligned for; $($vm.Name). vCPU assigned: $($getvCPUCount.ProcessorCount) of $totalCPU available`r`n"
        $vcpuStatus = 'Failed'
    }
}
If (!$vCPUOutput) {
    $vcpuDetails = 'Healthy'
    $vcpuStatus = 'Success'
}


#############################
## Check for old snapshots ##
#############################
<#
.Description
While snapshots are a nice technology for a quick test, or maybe for dev, they are not a backup
solution. Keeping snapshots (especially multiple snapshots) can cause huge performance hits over 
time, and can cause massive uncontrollable disk space usage growth. For this reason, a snapshot
should not exist unless it is an active test, temporary project step, or dev scenario.
#>
$snapshots = Get-VM | Get-VMSnapshot | Where-Object {$_.CreationTime -lt (Get-Date).AddDays(-30) }
ForEach ($snapshot in $snapshots) {
    $snapshotDetail += "A snapshot has been found for VM $($snapshot.vmname). The snapshot was created on $($snapshot.CreationTime)`r`n"
    $snapshotStatus = 'Failed'
}
If (!$snapshotDetail) {
    $snapshotDetail = 'Healthy'
    $snapshotStatus = 'Success'
}


#####################################
## Check for VMs runnning on AVHDX ##
#####################################
<#
.Description
AVHDX is the differencing file that is created when you make a snapshot. When you reboot or shutdown, the 
AVHDX will merge into the parent VMDK. If the changes are never merged from the AVHDX to the VMDK, this file 
can grow indefinitely. The true fix is to delete the snapshots and reboot, but at least rebooting or shutting 
down the VM without deleting the snapshots will merge the changes to ensure the AVHDX file size growth is 
controlled. To merge manually, check this article: https://www.nakivo.com/blog/merge-hyper-v-snapshots-step-step-guide/
#>
$VHDs = Get-VM | Get-VMHardDiskDrive
ForEach ($VHD in $VHDs){
    If ($vhd.path -match 'avhd') {
        $avhdxDetails += "$($VHD.VMName) is running on AVHD: $($VHD.path) `r`n"
        $avhdxStatus = 'Failed'
    }
}
If (!$avhdxDetails) {
    $avhdxDetails = 'Healthy'
    $avhdxStatus = 'Success'
}

##################################
## Check CPU compatibility mode ##
##################################
<#
.Description
Often, hosts will not have the same identical CPU in a cluster, so without checking the box for CPU
compatibility, this will prevent the VM from moving to other host resources without an identical CPU.
This can break the intended purpose of HA, so the recommendation is to always have this enabled.
#>
$cpuCompatVMs = 'VMs with CPU Compatibility disabled: '
ForEach ($vm in $runningVMs) {
    If (!(Get-VMProcessor -VMName $($vm.Name)).CompatibilityForMigrationEnabled) {
        $cpuCompatStatus = 'Failed'
        $cpuCompatVMs += "$($vm.Name)`r`n"
    }
}
If (!$cpuCompatStatus) {
    $cpuCompatStatus = 'Success'
}
If ($cpuCompatVMs -eq "VMs with CPU Compatibility disabled:`r`n") {
    $cpuCompatVMs = 'None'
}


#########################
## Find old unused VMs ##
######################### 
ForEach ($vm in $allVMs) {
    $vmLastUse = (Get-Item -Path $vm.HardDrives[0].Path).LastWriteTime
    If ($vmLastUse -lt ((Get-Date).AddDays(-90))) {
        $unusedVMs += "$($vm.Name)`r`n"
        $unusedVMStatus = 'Failed'
    }
}
If (!$unusedVMStatus) {
    $unusedVMStatus = 'Success'
    $unusedVMs = 'None'
}


####################################
## Detect if host is in a cluster ##
####################################
<#
If ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V).State -eq 'Enabled') {
    $hypervRole = $True
    $hypervCluster = (Get-VMHost).VirtualMachineMigrationEnabled
    If ($hypervCluster) {
        $hypervCluster = $True
    } Else {
        $hypervCluster = $False
    }
} Else {
    $hypervRole = $False
}
#>


"isStatus=$isStatus|isDetails=$isDetails|vcpuStatus=$vcpuStatus|vcpuDetails=$vcpuDetails|snapshotStatus=$snapshotStatus|snapshotDetail=$snapshotDetail|avhdxStatus=$avhdxStatus|avhdxDetails=$avhdxDetails|cpuCompatStatus=$cpuCompatStatus|cpuCompatVMs=$cpuCompatVMs|unusedVMStatus=$unusedVMStatus|unusedVMs=$unusedVMs"

$isStatus = $null
$isDetails = $null
$vcpuStatus = $null
$vcpuDetails = $null
$snapshotStatus = $null
$snapshotDetail = $null
$avhdxStatus = $null
$avhdxDetails = $null
$cpuCompatStatus = $null
$cpuCompatVMs = $null
$unusedVMStatus = $null
$unusedVMs = $null