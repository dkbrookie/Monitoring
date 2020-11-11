Function Get-PrinterStatus ($currentStatus) {
    switch ($currentStatus) {
         "0" { $printerStatus = "Ok" }
         "1" { $printerStatus = "Other" }
         "2" { $printerStatus = "No Error" }
         "3" { $printerStatus = "Low Paper" }
         "4" { $printerStatus = "No Paper" }
         "5" { $printerStatus = "Low Toner" }
         "6" { $printerStatus = "No Toner" }
         "7" { $printerStatus = "Door Open" }
         "8" { $printerStatus = "Jammed" }
         "9" { $printerStatus = "Service Requested" }
         "10" { $printerStatus = "Output Bin Full" }
         "11" { $printerStatus = "Paper Problem" }
         "12" { $printerStatus = "Cannot Print Page" }
         "13" { $printerStatus = "User Intervention Required" }
         "14" { $printerStatus = "Out of Memory" }
         "15" { $printerStatus = "Server Unknown" }
         default {$printerStatus = "Error (D)" }
    }
return ($printerStatus)
}

$printerStats = Get-WMIObject -class "Win32_Printer" -ComputerName $env:COMPUTERNAME -NameSpace "root\CIMV2"
$printServer = Get-WMIObject "Win32_PrintJob" -ComputerName $env:COMPUTERNAME | Where-Object { ($_.jobStatus -ne $null) -and ($_.jobStatus -ne "") -and ($_.jobStatus -ne "Printing") -and ($_.jobStatus -ne "Spooling") -and ($_.jobStatus -ne "Spooling | Printing")  }
Write-Output "--Printers--"
$printerStats | Select-Object Name, Systemname, @{Name="DetectedErrorState";Expression={mystatus $_.DetectedErrorState }}
ForEach ($printjob in $printServer) {
    If (($printjob.jobStatus) -and ($printjob.jobStatus -ne "")){
        Write-Output "--Job Status--"
        switch ($printjob.jobStatus) {
            default { 
                $printerDetails = $printerStats | Where-Object { $_.name -eq ("" + $printjob.Name.split(',')[0]) }
                $timeSubmitted = $printjob.TimeSubmitted
                $timeSubmitted = [System.Management.ManagementDateTimeConverter]::ToDateTime($timeSubmitted).ToUniversalTime();
                $output = "Printer: $($printerDetails.Name) | Time Submitted: $timeSubmitted | Print Owner: $($printjob.Owner) | Status: $($printjob.jobStatus) | Server: $env:COMPUTERNAME | Document Pending: $($printjob.Document)"
                $output
                #$printjob.Delete()
            }
        }
    }
}