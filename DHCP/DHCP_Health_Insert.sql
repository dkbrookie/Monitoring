INSERT INTO dkb_monitoring_ad (
    `ComputerID`
    ,`dhcpLeaseStatus`
    ,`conflictDetectionStatus`
    ,`fixLog`
    ,`logOutput`
    ,`dateLastUpdated`
)
VALUES (
    /*ComputerID*/'%ComputerID%'
    ,/*dhcpLeaseStatus*/'@dhcpLeaseStatus@'
    ,/*conflictDetectionStatus*/'@conflictDetectionStatus@'
    ,/*fixLog*/'@fixLog@'
    ,/*logOutput*/'@logOutput@'
    ,/*dateLastUpdated*/NOW()
)
ON DUPLICATE KEY UPDATE
    `dhcpLeaseStatus` = '@dhcpLeaseStatus@'
    ,`conflictDetectionStatus` = '@conflictDetectionStatus@'
    ,`fixLog` = '@fixLog@'
    ,`logOutput` = '@logOutput@'
    ,`dateLastUPdated` = NOW()