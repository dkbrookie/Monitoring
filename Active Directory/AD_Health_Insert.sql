INSERT INTO dkb_monitoring_ad (
    `ComputerID`
    ,`sysvolSmbConnection`
    ,`sysvolRepType`
    ,`sysvolRepTest`
    ,`sysvolFileRepTime`
    ,`unreachableDCs`
    ,`generalReplicationStatus`
    ,`generalRepFailDetails`
    ,`generalRepFailedDCs`
    ,`adRecycleBinEnabled`
    ,`timeSyncStatus`
    ,`maxTimeSyncVariance`
    ,`shadowCopyStatus`
    ,`latestShadowCopy`
    ,`forestTest`
    ,`forestLevel`
    ,`OS`
    ,`fixLog`
    ,`logOutput`
    ,`dateLastUpdated`
)
VALUES (
    /*ComputerID*/'%ComputerID%'
    ,/*sysvolSmbConnection*/'@sysvolSmbConnection@'
    ,/*sysvolRepType*/'@sysvolRepType@'
    ,/*sysvolRepTest*/'@sysvolRepTest@'
    ,/*sysvolFileRepTime*/'@sysvolFileRepTime@'
    ,/*unreachableDCs*/'@unreachableDCs@'
    ,/*generalReplicationStatus*/'@generalReplicationStatus@'
    ,/*generalRepFailDetails*/'@ProtectiogeneralRepFailDetailsnStatus@'
    ,/*generalRepFailedDCs*/'@generalRepFailedDCs@'
    ,/*adRecycleBinEnabled*/'@adRecycleBinEnabled@'
    ,/*timeSyncStatus*/'@timeSyncStatus@'
    ,/*maxTimeSyncVariance*/'@maxTimeSyncVariance@'
    ,/*shadowCopyStatus*/'@shadowCopyStatus@'
    ,/*latestShadowCopy*/'@latestShadowCopy@'
    ,/*forestTest*/'@forestTest@'
    ,/*forestLevel*/'@forestLevel@'
    ,/*OS*/'@OS@'
    ,/*fixLog*/'@fixLog@'
    ,/*logOutput*/'@logOutput@'
    ,/*dateLastUpdated*/NOW()
)
ON DUPLICATE KEY UPDATE
    `sysvolSmbConnection` = '@sysvolSmbConnection@'
    ,`sysvolRepType` = '@sysvolRepType@'
    ,`sysvolRepTest` = '@sysvolRepTest@'
    ,`sysvolFileRepTime` = '@sysvolFileRepTime@'
    ,`unreachableDCs` = '@unreachableDCs@'
    ,`generalReplicationStatus` = '@generalReplicationStatus@'
    ,`generalRepFailDetails` = '@generalRepFailDetails@'
    ,`generalRepFailedDCs` = '@generalRepFailedDCs@'
    ,`adRecycleBinEnabled` = '@adRecycleBinEnabled@'
    ,`timeSyncStatus` = '@timeSyncStatus@'
    ,`maxTimeSyncVariance` = '@maxTimeSyncVariance@'
    ,`shadowCopyStatus` = '@shadowCopyStatus@'
    ,`latestShadowCopy` = '@latestShadowCopy@'
    ,`forestTest` = '@forestTest@'
    ,`forestLevel` = '@forestLevel@'
    ,`os` = '@os@'
    ,`fixLog` = '@fixLog@'
    ,`logOutput` = '@logOutput@'
    ,`dateLastUPdated` = NOW()