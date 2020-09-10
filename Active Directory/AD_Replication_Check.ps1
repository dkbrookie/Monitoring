## Set acceptable time limit for replication last successful run
$timeSpan = New-TimeSpan -Hours 2

$domainControllers = Get-ADReplicationPartnerMetadata -Target * -Scope Server -EA 0
ForEach ($dc in $domainControllers) {
    $pattern = '(?<=\,)(.*?)(?=\,)'
    $dcName = $dc.Partner 
    $dcName = [regex]::replace((([regex]::match($dcName,$pattern)).value),'CN=','')
    Write-Output "Checking $dcName"
    $dcReplicatonSuccess = $dc.LastReplicationSuccess
    $dcFails = $dc.ConsecutiveReplicationFailures
    $lastReplication = $dc.LastReplicationSuccess
    If (((Get-Date) - $lastReplication) -gt $timeSpan) {
        If (!$allDCFails) {
            $allDCFails = "$($dcName): $dcFails Concurrent Replication Failures"
        } Else {
            $allDCFails += "`r`n$($dcName): $dcFails Concurrent Replication Failures"
        }
            
        $logOutput += "$dcName is failing replication. Last successful replication $dcReplicatonSuccess and currently has $dcFails consecutive failed replication attempts.`r`n"
        If (!$failedDCs) {
            $script:failedDCs = $dcName
        } Else {
            $script:failedDCs += "`r`n$dcName"
        }
        $status = 'Failed'
    } Else {
        $logOutput += "$dcName is successfully replicating! Last replication: $lastReplication`r`n"
        $status = 'Success'
    }
}

"status=$status|allDCFails=$allDCFails|failedDCs=$failedDCs|logOutput=$logOutput"

## For testing
$status = $null
$allDCFails = $null
$failedDCs = $null
$logOutput = $null

## Most recent failure event in the last hour to test
# Get-ADForest | Select-Object -ExpandProperty GlobalCatalogs | Get-ADReplicationFailure | Where-Object {$_.firstfailuretime -gt ((get-date).addhours(-1))} | Sort-Object firstfaluretime | Select-Object -first 1