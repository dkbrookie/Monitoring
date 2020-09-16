INSERT
	INTO dkb_monitoring_ad
	(
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
    ,`logOutput`
	)
VALUES
	(
	/*ComputerID*/%ComputerID%
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
    ,/*logOutput*/'@logOutput@'
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
    ,`logOutput` = '@logOutput@'
