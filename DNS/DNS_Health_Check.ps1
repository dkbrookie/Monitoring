## Gather the latest error and warning eventlogs generated in the DNS Server log
Try {
    $logOutput += "Getting latest dns eventlog errors and warnings..."
    $dnsLogs = Get-WinEvent -FilterHashtable @{ LogName = 'DNS Server'; Level = 2,3; StartTime = [datetime]::Today.AddDays(-7) } | Sort-Object Message -Unique | Format-Table -AutoSize -HideTableHeaders -Wrap | Out-String
    If ($dnsLogs) {
        $logOutput += [string]$dnsLogs
    } Else {
        $logOutput += "Found 0 error/warning events in the DNS eventlog.`r`n"
    }
} Catch {
    $logOutput += "There was an issue when trying to gather the latest eventlogs. Error output: $Error`r`n"
    Break
}

"errors=$errorsOut|logOutput=$logOutput|fixLog=$fixLog"

$logOutput = $null
$fixLog = $null