## Check If An NTFRS Subscriber Object Exists To Determine If NTFRS Is Being Used Instead Of DFS-R
$SearcherNTFRS = New-Object DirectoryServices.DirectorySearcher
$SearcherNTFRS.Filter = "(&(objectClass=nTFRSSubscriber)(name=Domain System Volume (SYSVOL share)))"
$SearcherNTFRS.SearchRoot = $dcObjectPath
$ntfrsSubscriptionObject = $SearcherNTFRS.FindAll()
If ($ntfrsSubscriptionObject -ne $null) {
    $logOutput += "SYSVOL replication mechanism being used: NTFRS`r`n"
    $sysvolRepType = 'NTFRS'
    $sysvolRootPathOnSourcingRWDC = $ntfrsSubscriptionObject | %{$_.Properties.frsrootpath}
}

## Check If An DFS-R Subscriber Object Exists To Determine If DFS-R Is Being Used Instead Of NTFRS
$SearcherDFSR = New-Object DirectoryServices.DirectorySearcher
$SearcherDFSR.Filter = "(&(objectClass=msDFSR-Subscription)(name=SYSVOL Subscription))"
$SearcherDFSR.SearchRoot = $dcObjectPath
$dfsrSubscriptionObject = $SearcherDFSR.FindAll()
If ($dfsrSubscriptionObject -ne $null) {
    $logOutput += "SYSVOL replication mechanism being used: DFS-R`r`n"
    $sysvolRepType = 'DFS-R'
    $sysvolRootPathOnSourcingRWDC = $dfsrSubscriptionObject | %{$_.Properties."msdfsr-rootpath"}
}

$sysvolRootPathOnSourcingRWDC = $sysvolRootPathOnSourcingRWDC  | Select-Object -First 1

Set-Content -Path "$sysvolRootPathOnSourcingRWDC\Scripts\repTest.txt" -Value 'testRep'