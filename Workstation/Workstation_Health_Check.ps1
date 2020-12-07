## Find devices with missing drivers
$logOutput += "`r`n`r`n`r`n====================================`r`n"
$logOutput += "========Missing Driver Check========`r`n"
$logOutput += "====================================`r`n`r`n`r`n"
$missingDrivers = Get-WmiObject Win32_PNPEntity -ErrorAction Ignore | Where-Object{$_.Availability -eq 11 -or $_.Availability -eq 12}
If ($missingDrivers) {
    $missingDriverStatus = 'Failed'
    $logOutput += $missingDrivers
} Else {
    $missingDriverStatus = 'Success'
    $logOutput += "Verified no missing drivers!`r`n"
}

## Get hardware devices in Error, Degraded, or Unknown states
$logOutput += "`r`n`r`n===========================================`r`n"
$logOutput += "========Device Manager Health Check========`r`n"
$logOutput += "===========================================`r`n`r`n`r`n"
$deviceIssues = Get-PnpDevice -PresentOnly -Status ERROR,DEGRADED,UNKNOWN -ErrorAction Ignore
If ($deviceIssues) {
    $deviceIssueStatus = 'Failed'
    $logOutput += "`r`nFound devices in Error, Degraded, or Unknown statuses in device manager. See output below...`r`n"
    $logOutput += $deviceIssues | Out-String
} Else {
    $deviceIssueStatus = 'Success'
    $logOutput += "Verified no devices in Error, Degraded, or Unknown states in device manager.`r`n"
}

## Monitor user experience score, output issues if any found
$logOutput += "`r`n`r`n================================================`r`n"
$logOutput += "========Windows Reliability Health Check========`r`n"
$logOutput += "================================================`r`n`r`n`r`n"
$indexScoreExpected = "5.0"
$reliabilityIndexAvgScore = [math]::Round((((Get-CimInstance -ClassName win32_reliabilitystabilitymetrics).SystemStabilityIndex | Measure-Object -Average).Average),2)
$Records = Get-CimInstance -ClassName win32_reliabilityRecords | Where-Object { $_.SourceName -eq 'Application Error'}
$Metrics = Get-CimInstance -ClassName win32_reliabilitystabilitymetrics | Select-Object -First 1

$CombinedMetrics = [PSCustomObject]@{
    SystemStabilityIndex = $Metrics.SystemStabilityIndex
    'Start Date'         = $Metrics.StartMeasurementDate
    'End Date'           = $Metrics.EndMeasurementDate
    'Stability Records'  = $Records
}

If ($CombinedMetrics.SystemStabilityIndex -lt $indexScoreExpected) {
    $reliabilityStatus = 'Failed'
    ## Trying out combining events by unqique app names to avoid spam output...but lose how many times each event happened so will need to include a count too. WIP.
    $logOutput += "The system stability index is $reliabilityIndexAvgScore, which is less than our designated critical score of $indexScoreExpected. The MS threshold of healthy systems says ideally this is 6.0 or better. This computer might not be performing in an optimal state. See below output for potential causes reported in reliability manager...`r`n"  
    $logOutput += $CombinedMetrics.'Stability Records' | Sort-Object ProductName -Unique | Out-String
} Else {
    $reliabilityStatus = 'Success'
    $logOutput += "Verified reliability score greater than $indexScoreExpected`r`n"
}

"errorOut=$Error|missingDriverStatus=$missingDriverStatus|deviceIssueStatus=$deviceIssueStatus|reliabilityStatus=$reliabilityStatus|logOutput=$logOutput"

$missingDriverStatus = $null
$deviceIssueStatus = $null
$reliabilityStatus = $null
$logOutput = $null