
## Monitor user experience score, output issues if any found
$indexScoreExpected = "6.0"
$reliabilityIndexAvgScore = [math]::Round((((Get-CimInstance -ClassName win32_reliabilitystabilitymetrics).SystemStabilityIndex | Measure-Object -Average).Average),2)
$Records = Get-CimInstance -ClassName win32_reliabilityRecords | Where-Object { $_.SourceName -eq 'Application Error'}
 
$CombinedMetrics = [PSCustomObject]@{
    SystemStabilityIndex = $Metrics.SystemStabilityIndex
    'Start Date'         = $Metrics.StartMeasurementDate
    'End Date'           = $Metrics.EndMeasurementDate
    'Stability Records'  = $Records
}
 
if ($CombinedMetrics.SystemStabilityIndex -lt $indexScoreExpected) {
    ## Trying out combining events by unqique app names to avoid spam output...but lose how many times each event happened so will need to include a count too. WIP.
    $CombinedMetrics.'Stability Records' | Sort-Object ProductName -Unique
    Write-Warning "The system stability index is $reliabilityIndexAvgScore, which is less than $indexScoreExpected, the MS threshold of healthy systems. This computer might not be performing in an optimal state."
}