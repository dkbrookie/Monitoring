INSERT INTO dkb_monitoring_hyperv (
    `ComputerID`
    ,`isStatus`
    ,`isDetails`
    ,`vcpuStatus`
    ,`vcpuDetails`
    ,`snapshotStatus`
    ,`snapshotDetail`
    ,`avhdxStatus`
    ,`avhdxDetails`
    ,`cpuCompatStatus`
    ,`cpuCompatVMs`
    ,`unusedVMStatus`
    ,`uunusedVMs`
    ,`dateLastUpdated`
)
VALUES (
    /*ComputerID*/'%ComputerID%'
    ,/*isStatus*/'@isStatus@'
    ,/*isDetails*/'@isDetails@'
    ,/*vcpuStatus*/'@vcpuStatus@'
    ,/*vcpuDetails*/'@vcpuDetails@'
    ,/*snapshotStatus*/'@snapshotStatus@'
    ,/*snapshotDetail*/'@snapshotDetail@'
    ,/*avhdxStatus*/'@ProtectioavhdxStatusnStatus@'
    ,/*avhdxDetails*/'@avhdxDetails@'
    ,/*cpuCompatStatus*/'@cpuCompatStatus@'
    ,/*cpuCompatVMs*/'@cpuCompatVMs@'
    ,/*unusedVMStatus*/'@unusedVMStatus@'
    ,/*unusedVMs*/'@unusedVMs@'
    ,/*dateLastUpdated*/NOW()
)
ON DUPLICATE KEY UPDATE
    `isStatus` = '@isStatus@'
    ,`isDetails` = '@isDetails@'
    ,`vcpuStatus` = '@vcpuStatus@'
    ,`vcpuDetails` = '@vcpuDetails@'
    ,`snapshotStatus` = '@snapshotStatus@'
    ,`snapshotDetail` = '@snapshotDetail@'
    ,`avhdxStatus` = '@avhdxStatus@'
    ,`avhdxDetails` = '@avhdxDetails@'
    ,`cpuCompatStatus` = '@cpuCompatStatus@'
    ,`cpuCompatVMs` = '@cpuCompatVMs@'
    ,`unusedVMStatus` = '@unusedVMStatus@'
    ,`unusedVMs` = '@unusedVMs@'
    ,`dateLastUPdated` = NOW()