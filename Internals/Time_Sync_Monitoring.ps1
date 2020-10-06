Workflow Get-VSystemTimeSynchronization
{
    <#
    .SYNOPSIS
         Get configured NTP server (source) and date and time of the last time synchronization. Raise error when last time synchronization was a long time ago or when the NTP server (source) is wrong.

    .DESCRIPTION
        Developer
            Developer: Rudolf Vesely, http://rudolfvesely.com/
            Copyright (c) Rudolf Vesely. All rights reserved
            License: Free for private use only

            "V" is the first letter of the developer's surname. The letter is used to distingue Rudolf Vesely's cmdlets from the other cmdlets.

        Description
            Get configured NTP server (source) and date and time of the last time synchronization. Raise error when last time synchronization was a long time ago or when the NTP server (source) is wrong.

        Requirements
            Developed and tested using PowerShell 4.0.

    .PARAMETER ComputerName
        Computer names of remote devices. If not set then local device will be processed.

    .PARAMETER RequiredSourceName
        For example: @('0.pool.ntp.org', '1.pool.ntp.org', '2.pool.ntp.org', '3.pool.ntp.org')

        If specified then the results is False when the current source is not one of the defined value.

    .PARAMETER RequiredSourceTypeConfiguredInRegistry
        Error will raise when the current source is not one of the sources configured in Windows Registry.

        Locations in Windows Registry:
            HKLM:\SOFTWARE\Policies\Microsoft\W32Time\Parameters
            or
            HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters

    .PARAMETER RequiredSourceTypeNotLocal
        Error will raise when the current source is local CMOS (internal clock).

    .PARAMETER RequiredSourceTypeNotByHost
        Error will raise when the current source is Hyper-V service.

    .PARAMETER LastTimeSynchronizationMaximumNumberOfSeconds
        Maximum number of seconds of the last time synchronization.

        If specified then the results is False when the last time synchronization was a long time ago then the specified number.

    .PARAMETER CompareWithNTPServerName
        See help from: Test-VSystemTimeSynchronization

    .PARAMETER CompareWithNTPServerMaximumTimeDifferenceSeconds
        See help from: Test-VSystemTimeSynchronization

    .PARAMETER IgnoreError
        See help from: Test-VSystemTimeSynchronization

    .EXAMPLE
        '    - Get date from the specified remote devices (servers)'
        '    - Return date and time of the last time synchronization'
        '    - Raise error when the date and time of last synchronization is unknwon (unspecified)'
        Get-VSystemTimeSynchronization `
            -ComputerName hyperv0, hyperv1, hyperv2 `
            -Verbose

    .EXAMPLE
        'Raise error when the date and time of last synchronization was a long time ago (more then the specified number of seconds)'
        Get-VSystemTimeSynchronization `
            -LastTimeSynchronizationMaximumNumberOfSeconds 3600 -Verbose

    .EXAMPLE
        'Raise error when the current source is not equal one of the defined values'
        Get-VSystemTimeSynchronization `
            -RequiredSourceName '0.pool.ntp.org', '1.pool.ntp.org', '2.pool.ntp.org', '3.pool.ntp.org'  `
            -Verbose

    .EXAMPLE
        'Raise error when the current source is not one of the values defined in Windows Registry'
        Get-VSystemTimeSynchronization `
            -RequiredSourceTypeConfiguredInRegistry:$true  `
            -Verbose

    .EXAMPLE
        'Raise error when the current source is equal to internal clock or synchronization is done by Hyper-V Time synchronization service'
        Get-VSystemTimeSynchronization `
            -RequiredSourceTypeNotLocal:$true `
            -RequiredSourceTypeNotByHost:$true `
            -Verbose

    .EXAMPLE
        '    - Get date from the specified remote devices (servers)'
        '    - Raise error when the time difference between the remote device and defined NTP server it too high'
        '    - NTP server is defined by IP address (IPv6) but of course it could be specified by DNS name'
        '    - Ignore when it is not possible to connect the NTP server (remote device may have may have closed firewall)'
        Get-VSystemTimeSynchronization `
            -ComputerName hyperv0, hyperv1, hyperv2 `
            -RequiredSourceTypeNotLocal:$true `
            -CompareWithNTPServerName 'fd12:3456::0045' `
            -CompareWithNTPServerMaximumTimeDifferenceSeconds 10 `
            -IgnoreError CompareWithNTPServerNoConnection `
            -Verbose

    .INPUTS

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .LINK
        https://techstronghold.com/
    #>

    [CmdletBinding(
        DefaultParametersetName = 'RequiredSourceName',
        HelpURI = 'https://techstronghold.com/',
        ConfirmImpact = 'Medium'
    )]

    Param
    (
        [Parameter(
            Mandatory = $false
            # Position = ,
            # ParameterSetName = ''
        )]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$ComputerName,

        [Parameter(
            Mandatory = $false,
            Position = 0,
            ParameterSetName = 'RequiredSourceName'
        )]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$RequiredSourceName,

        [Parameter(
            Mandatory = $false
            # Position = ,
            # ParameterSetName = ''
        )]
        [bool]$RequiredSourceTypeConfiguredInRegistry,

        [Parameter(
            Mandatory = $false
            # Position = ,
            # ParameterSetName = ''
        )]
        [bool]$RequiredSourceTypeNotLocal,

        [Parameter(
            Mandatory = $false
            # Position = ,
            # ParameterSetName = ''
        )]
        [bool]$RequiredSourceTypeNotByHost,

        [Parameter(
            Mandatory = $false
            # Position = ,
            # ParameterSetName = ''
        )]
        [AllowNull()]
        [int]$LastTimeSynchronizationMaximumNumberOfSeconds,

        [Parameter(
            Mandatory = $false
            # Position = ,
            # ParameterSetName = ''
        )]
        [string]$CompareWithNTPServerName,

        [Parameter(
            Mandatory = $false
            # Position = ,
            # ParameterSetName = ''
        )]
        [int]$CompareWithNTPServerMaximumTimeDifferenceSeconds = 5,

        [Parameter(
            Mandatory = $false
            # Position = ,
            # ParameterSetName = ''
        )]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$IgnoreError
    )

    # Configurations
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $inlineScriptErrorItems          = $null



    <#
    Protection against exception when this workflow is used from another workflow
        Exception: The variable '$__PSUsingVariable_SomeVar' cannot be retrieved because it has not been set.
    #>

    if (!$RequiredSourceName)         { $RequiredSourceName        = @() }
    if (!$CompareWithNTPServerName)   { $CompareWithNTPServerName  = '' }

    try
    {
        InlineScript
        {
            <#
            Initializations
            #>

            # Configurations
            $ErrorActionPreference = 'Stop'
            if ($PSBoundParameters['Debug']) { $DebugPreference = 'Continue' }
            Set-PSDebug -Strict
            Set-StrictMode -Version Latest



            <#
            Variables
            #>

            $outputItem = [PsCustomObject]@{
                DateTimeUtc                                = $null

                ComputerNameBasic                          = $env:COMPUTERNAME.ToLower()
                ComputerNameNetBIOS                        = $env:COMPUTERNAME
                ComputerNameFQDN                           = $null

                # For example: @('0.pool.ntp.org', '1.pool.ntp.org', '2.pool.ntp.org', '3.pool.ntp.org')
                ConfiguredNTPServerName                    = $null

                # For example: '0.pool.ntp.org,0x1 1.pool.ntp.org,0x1 2.pool.ntp.org,0x1 3.pool.ntp.org,0x1'
                ConfiguredNTPServerNameRaw                 = $null

                # True if defined by policy
                ConfiguredNTPServerByPolicy                = $null

                SourceName                                 = $null
                SourceNameRaw                              = $null

                LastTimeSynchronizationDateTime            = $null
                LastTimeSynchronizationElapsedSeconds      = $null

                ComparisonNTPServerName                    = $(if ($Using:CompareWithNTPServerName) { $Using:CompareWithNTPServerName } else { $null })
                ComparisonNTPServerTimeDifferenceSeconds   = $null

                # Null when no source is required, True / False when it is required
                StatusRequiredSourceName                   = $null

                # Null when no type is required, True / False when it is required
                StatusRequiredSourceType                   = $null

                # True when date is not unknown, False when it is unknown
                StatusDateTime                             = $null

                # Null when maximum of seconds was not specified, True / False when it was specified
                StatusLastTimeSynchronization              = $null

                # Null when no comparison or when not connection and error should be ignored, True / False when number of seconds was obtained
                StatusComparisonNTPServer                  = $null

                Status                                     = $null
                StatusEvents                               = @()
                Error                                      = $null
                ErrorEvents                                = @()
            }



            <#
            Start W32Time service
            #>

            try
            {
                if ((Get-Service -Name W32Time).Status -ne 'Running')
                {
                    Write-Verbose -Message '[Get] [Start service] [Verbose] Start service: W32Time (Windows Time)'
                    Start-Service -Name W32Time
                }
            }
            catch
            {
                $outputItem.ErrorEvents += ('[Get] [Start service] [Exception] {0}' -f $_.Exception.Message)
            }



            <#
            Gather data
            #>

            try
            {
                # W32tm
                $w32tmOutput = & 'w32tm' '/query', '/status'

                # FQDN
                $ipGlobalProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
                if ($ipGlobalProperties.DomainName)
                {
                    $outputItem.ComputerNameFQDN = '{0}.{1}' -f
                        $ipGlobalProperties.HostName, $ipGlobalProperties.DomainName
                }
                else
                {
                    $outputItem.ComputerNameFQDN = $null
                }
            }
            catch
            {
                $outputItem.ErrorEvents += ('[Get] [Gather data] [Exception] {0}' -f $_.Exception.Message)
            }



            <#
            Configured NTP Server
            #>

            try
            {
                if (Test-Path -Path HKLM:\SOFTWARE\Policies\Microsoft\W32Time\Parameters -PathType Container)
                {
                    $configuredNtpServerNameRegistryPolicy = Get-ItemProperty `
                        -Path HKLM:\SOFTWARE\Policies\Microsoft\W32Time\Parameters `
                        -Name 'NtpServer' -ErrorAction SilentlyContinue |
                        Select-Object -ExpandProperty NtpServer
                }
                else
                {
                    $configuredNtpServerNameRegistryPolicy = $null
                }

                if ($configuredNtpServerNameRegistryPolicy)
                {
                    $outputItem.ConfiguredNTPServerByPolicy = $true

                    # Policy override
                    $outputItem.ConfiguredNTPServerNameRaw = $configuredNtpServerNameRegistryPolicy.Trim()
                }
                else
                {
                    $outputItem.ConfiguredNTPServerByPolicy = $false

                    # Exception if not exists
                    $outputItem.ConfiguredNTPServerNameRaw = ((Get-ItemProperty `
                        -Path HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters -Name 'NtpServer').NtpServer).Trim()
                }

                if ($outputItem.ConfiguredNTPServerNameRaw)
                {
                    $outputItem.ConfiguredNTPServerName = $outputItem.ConfiguredNTPServerNameRaw.Split(' ') -replace ',0x.*'
                }
            }
            catch
            {
                $outputItem.ErrorEvents += ('[Get] [Configured NTP Server] [Exception] {0}' -f $_.Exception.Message)
            }



            <#
            Source
            #>

            try
            {
                $sourceNameRaw = $w32tmOutput | Select-String -Pattern '^Source:'

                if ($sourceNameRaw)
                {
                    $sourceNameRaw =
                        $sourceNameRaw.ToString().Replace('Source:', '').Trim()

                    $outputItem.SourceNameRaw = $sourceNameRaw
                    $outputItem.SourceName = $sourceNameRaw -replace ',0x.*'



                    <#
                    Source: Test: Name
                    #>

                    if ($Using:RequiredSourceName)
                    {
                        if ($Using:RequiredSourceName -contains $outputItem.SourceName)
                        {
                            $outputItem.StatusRequiredSourceName = $true
                        }
                        else
                        {
                            $outputItem.StatusRequiredSourceName = $false

                            $outputItem.ErrorEvents += ('[Get] [Source name] [Error] Current: {0}; Required: {1}' -f
                                $outputItem.SourceName, ($Using:RequiredSourceName -join ', '))
                        }
                    }



                    <#
                    Source: Test: Type
                    #>

                    if ($Using:RequiredSourceTypeConfiguredInRegistry -or $Using:RequiredSourceTypeNotLocal -or $Using:RequiredSourceTypeNotByHost)
                    {
                        $outputItem.StatusRequiredSourceType = $true

                        if (($Using:RequiredSourceTypeConfiguredInRegistry -or $Using:RequiredSourceTypeNotLocal) -and
                            ($outputItem.SourceNameRaw  -eq 'Local CMOS Clock' -or
                            $outputItem.SourceNameRaw  -eq 'Free-running System Clock'))
                        {
                            $outputItem.StatusRequiredSourceType = $false

                            $outputItem.ErrorEvents += ('[Get] [Source type] [Error] Time synchronization source: Local')
                        }

                        if (($Using:RequiredSourceTypeConfiguredInRegistry -or $Using:RequiredSourceTypeNotByHost) -and
                            $outputItem.SourceNameRaw  -eq 'VM IC Time Synchronization Provider')
                        {
                            $outputItem.StatusRequiredSourceType = $false

                            $outputItem.ErrorEvents += ('[Get] [Source type] [Error] Time synchronization source: Hyper-V')
                        }

                        if ($Using:RequiredSourceTypeConfiguredInRegistry -and
                            $outputItem.ConfiguredNTPServerName -notcontains $outputItem.SourceName)
                        {
                            $outputItem.StatusRequiredSourceType = $false

                            $outputItem.ErrorEvents += ('[Get] [Source type] [Error] Not equal to one of the NTP servers that are define in Windows Registry')
                        }
                    }
                }
                else
                {
                    $outputItem.ErrorEvents += '[Get] [Source] [Error] Data from w32tm was not obtained'
                }
            }
            catch
            {
                $outputItem.ErrorEvents += ('[Get] [Source] [Exception] {0}' -f $_.Exception.Message)
            }



            <#
            Last time synchronization
            #>

            try
            {
                $lastTimeSynchronizationDateTimeRaw = $w32tmOutput |
                    Select-String -Pattern '^Last Successful Sync Time:'

                $outputItem.StatusDateTime = $false

                if ($lastTimeSynchronizationDateTimeRaw)
                {
                    $lastTimeSynchronizationDateTimeRaw =
                        $lastTimeSynchronizationDateTimeRaw.ToString().Replace('Last Successful Sync Time:', '').Trim()



                    <#
                    Last time synchronization: Test: Date and time
                    #>

                    if ($lastTimeSynchronizationDateTimeRaw -eq 'unspecified')
                    {
                        $outputItem.ErrorEvents += '[Last time synchronization] [Error] Date and time: Unknown'
                    }
                    else
                    {
                        $outputItem.LastTimeSynchronizationDateTime = [DateTime]$lastTimeSynchronizationDateTimeRaw
                        $outputItem.LastTimeSynchronizationElapsedSeconds = [int]((Get-Date) - $outputItem.LastTimeSynchronizationDateTime).TotalSeconds

                        $outputItem.StatusDateTime = $true



                        <#
                        Last time synchronization: Test: Maximum number of seconds
                        #>

                        if ($Using:LastTimeSynchronizationMaximumNumberOfSeconds -gt 0)
                        {
                            if ($outputItem.LastTimeSynchronizationElapsedSeconds -eq $null -or
                                $outputItem.LastTimeSynchronizationElapsedSeconds -lt 0 -or
                                $outputItem.LastTimeSynchronizationElapsedSeconds -gt $Using:LastTimeSynchronizationMaximumNumberOfSeconds)
                            {
                                $outputItem.StatusLastTimeSynchronization = $false

                                $outputItem.ErrorEvents += ('[Get] [Last time synchronization] [Error] Elapsed: {0} seconds; Defined maximum: {1} seconds' -f
                                    $outputItem.LastTimeSynchronizationElapsedSeconds, $Using:LastTimeSynchronizationMaximumNumberOfSeconds)
                            }
                            else
                            {
                                $outputItem.StatusLastTimeSynchronization = $true
                            }
                        }
                    }
                }
                else
                {
                    $outputItem.ErrorEvents += '[Get] [Last time synchronization] [Error] Data from w32tm was not obtained'
                }
            }
            catch
            {
                $outputItem.ErrorEvents += ('[Get] [Last time synchronization] [Exception] {0}' -f $_.Exception.Message)
            }



            <#
            Compare time with defined NTP server
            #>

            if ($Using:CompareWithNTPServerName)
            {
                $outputItem.StatusComparisonNTPServer = $false

                try
                {
                    $w32tmOutput = & 'w32tm' '/stripchart',
                        ('/computer:{0}' -f $Using:CompareWithNTPServerName),
                        '/dataonly', '/samples:1' |
                        Select-Object -Last 1

                    if ($w32tmOutput  -match '\.\d+s$')
                    {
                        $outputItem.ComparisonNTPServerTimeDifferenceSeconds = [double]($w32tmOutput -replace '.* |s$')



                        <#
                        Compare time with defined NTP server: Test
                        #>

                        if ($outputItem.ComparisonNTPServerTimeDifferenceSeconds -eq $null -or
                            $outputItem.ComparisonNTPServerTimeDifferenceSeconds -lt ($Using:CompareWithNTPServerMaximumTimeDifferenceSeconds * -1) -or
                            $outputItem.ComparisonNTPServerTimeDifferenceSeconds -gt $Using:CompareWithNTPServerMaximumTimeDifferenceSeconds)
                        {
                            $outputItem.ErrorEvents += ('[Get] [Compare with NTP] [Error] Elapsed: {0} seconds; Defined maximum: {1} seconds' -f
                                $outputItem.ComparisonNTPServerTimeDifferenceSeconds, $Using:CompareWithNTPServerMaximumTimeDifferenceSeconds)
                        }
                        else
                        {
                            $outputItem.StatusComparisonNTPServer = $true
                        }
                    }
                    else
                    {
                        $message = ('[Get] [Compare with NTP]: [Error] No connection')

                        if ($Using:IgnoreError -contains 'CompareWithNTPServerNoConnection')
                        {
                            $outputItem.StatusComparisonNTPServer = $true

                            $outputItem.StatusEvents += $message
                        }
                        else
                        {
                            $outputItem.ErrorEvents += $message
                        }
                    }
                }
                catch
                {
                    $outputItem.ErrorEvents += ('[Get] [Compare with NTP]: Exception: {0}' -f $_.Exception.Message)
                }
            }



            <#
            Return
            #>

            if ($outputItem.ErrorEvents)
            {
                Write-Warning -Message ('[Get] Results: False: {0}' -f ($outputItem.ErrorEvents -join "; "))

                $outputItem.Status  = $false
                $outputItem.Error   = $true
            }
            else
            {
                $outputItem.Status  = $true
                $outputItem.Error   = $false
            }

            $outputItem.DateTimeUtc = (Get-Date).ToUniversalTime()
            $outputItem.SourceName
        } -PSComputerName $ComputerName `
            -PSPersist:$false `
            -PSError $inlineScriptErrorParallelItems
    }



    <#
    Remoting: Error handling
    #>

    <#
    Single device in InlineScript -PSComputerName
    #>

    catch [System.Management.Automation.Remoting.PSRemotingTransportException]
    {
        $inlineScriptErrorItems = $_
    }



    <#
    Multiple devices in InlineScript -PSComputerName
    #>

    if ($inlineScriptErrorParallelItems) { $inlineScriptErrorItems = $inlineScriptErrorParallelItems }



    <#
    Error handling
    #>

    foreach ($inlineScriptErrorFullItem in $inlineScriptErrorItems)
    {
        # Exceptions from paralled has "Exception" property
        if ($inlineScriptErrorFullItem.PSObject.Properties.Name -eq 'Exception')
        {
            $inlineScriptErrorItem = $inlineScriptErrorFullItem.Exception
        }
        else
        {
            $inlineScriptErrorItem = $inlineScriptErrorFullItem
        }

        # Ignore defined errors
        if ($IgnoreError -contains 'WrongComputerName' -and
            ($inlineScriptErrorItem.ErrorRecord.CategoryInfo | Select-Object -First 1 -ExpandProperty Category) -eq 'ResourceUnavailable' -and
            $inlineScriptErrorItem.TransportMessage -like 'The network path was not found.*')
        {
            Write-Warning -Message 'Device does not exists (not in DNS).'
        }
        elseif ($IgnoreError -contains 'DeviceIsNotAccessible' -and
            ($inlineScriptErrorItem.ErrorRecord.CategoryInfo | Select-Object -First 1 -ExpandProperty Category) -eq 'ResourceUnavailable' -and
            $inlineScriptErrorItem.TransportMessage -like '*Verify that the specified computer name is valid, that the computer is accessible over the network*')
        {
            Write-Warning -Message 'Device exists (defined in DNS) but it is not reachable (not running, FW issue, etc.).'
        }
        else
        {
            # Terminating error
            Write-Error -Exception $inlineScriptErrorItem.ErrorRecord.Exception
        }
    }
}