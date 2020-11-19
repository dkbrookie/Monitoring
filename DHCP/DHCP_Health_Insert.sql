INSERT INTO dkb_monitoring_dhcp (
    `ComputerID`
    ,`DhcpLeaseStatus`
    ,`ConflictDetectionStatus`
    ,`CreateTicket`
    ,`FixLog`
    ,`LogOutput`
    ,`DateLastUpdated`
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
    `DhcpLeaseStatus` = '@dhcpLeaseStatus@'
    ,`ConflictDetectionStatus` = '@conflictDetectionStatus@'
    ,`CreateTicket` = '@CreateTicket@'
    ,`FixLog` = '@fixLog@'
    ,`LogOutput` = '@logOutput@'
    ,`DateLastUPdated` = NOW()