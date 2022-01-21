## Set script constants
$launchPadName = 'DKB Launch Pad'
## If the EXE has spaces the actual EXE name in the install dir will have underscores instead of spaces so
## accounting for that here.
$launchPadExeName = $launchPadName -replace (' ','_')
$psexecUrl = 'https://download.sysinternals.com/files/PSTools.zip'
$psexecDir = "$env:windir\LTSvc\Packages\Software\PSExec"
$psexecZip = "$psexecDir\PSExec.zip"
$psexecExe = "$psexecDir\PSExec.exe"
$launchPadExe = "${env:ProgramFiles(x86)}\DeskDirector Portal\$launchPadExeName.exe"
## Get a list of all users currently logged in to the machine
$users = ((quser) -replace '^>', '') -replace '\s{2,}', ',' | ConvertFrom-Csv
## Check each user to see if $launchPadName is running on every user session (needed for RDP servers)
ForEach ($user in $users) {
    ## Check for the $launchPadName running process on the individual user console number level
    $launchPadRun = Get-Process -Name $launchPadExeName -EA 0 | Where-Object { $_.SessionId -eq $user.ID }
    If ($launchPadRun) {
        [array]$logOutput += "Verified $launchPadName is running on $($user.Username)"
    } Else {
        [array]$logOutput += "$launchPadName is not running on $($user.Username), starting process"
        ## PSExec is the only tool that allows you to start a process on a specific user console number.
        ## Check to see if PSExec is downloaded, then download it if it's missing
        
        ## Create the PSExec dir if it doens't exist
        If (!(Test-Path $psexecDir -PathType Container)) {
            New-Item -Path $psexecDir -ItemType Directory | Out-Null`
        }
        If (!(Test-Path $psexecExe -PathType Leaf)) {
            ## Download PSExec zip
            (New-Object System.Net.WebClient).DownloadFile($psexecUrl,$psexecZip)
            ## Unzip PSExec
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($psexecZip, $psexecDir)
        }

        ## Set the console number to its own var since psexec passthrough doesn't like the .value method
        $consoleNumber = $user.Id
        ## Start $launchPadName on the console number we just set
        &$psexecExe -accepteula -i $consoleNumber -d $launchPadExe
        ## Set this var to $null so when we restart the loop on the next user the script doesn't save
        ## the state of the process for the current user.
        $launchPadRun = $null
    }
}

## Format output to put one line of text per line out
$logOutput -join "n"
"logOutput=$logOutput"