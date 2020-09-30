$logOutput = $null

## Clear The Screen
Clear-Host

## Some Constants
$continue = $true
$cleanupTempObject = $true
$os = (Get-CimInstance Win32_OperatingSystem).Caption

## The Function To Test The Port Connection
Function PortConnectionCheck($fqdnDC,$port,$timeOut) {
	$tcpPortSocket = $null
	$portConnect = $null
    $tcpPortWait = $null
    ## For some reason the socket test on 445 sometimes fails if you use the full FQDN so we're removing
    ## the .domain.xx from the end of the host name we're trying to test
    $fqdnDC = ($fqdnDC) -replace (".$($dc.Domain.Name)",'')
	$tcpPortSocket = New-Object System.Net.Sockets.TcpClient
	$portConnect = $tcpPortSocket.BeginConnect($fqdnDC,$port,$null,$null)
    $tcpPortWait = $portConnect.AsyncWaitHandle.WaitOne($timeOut,$false)
	If(!$tcpPortWait) {
		$tcpPortSocket.Close()
		Return "ERROR"
	} Else {
		#$error.Clear()
		$ErrorActionPreference = "SilentlyContinue"
		$tcpPortSocket.EndConnect($portConnect) | Out-Null
		If (!$?) {
			Return "ERROR"
		} Else {
			Return "SUCCESS"
		}
		$tcpPortSocket.Close()
		$ErrorActionPreference = "Continue"
	}
}


##################
## Get DC FQDNs ##
##################
## Get The FQDN Of The Local AD Domain From The Server This Script Is Executed On
$ADDomainToWriteTo = $(Get-WmiObject -Class Win32_ComputerSystem).Domain


################################################
## Get List Of Directory Servers In AD Forest ##
################################################
$ThisADForest = [DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
$configNCDN = $ThisADForest.schema.Name.Substring(("CN=Schema,").Length)
$searchRootNTDSdsa = [ADSI]"LDAP://CN=Sites,$configNCDN"
$searcherNTDSdsaRW = New-Object System.DirectoryServices.DirectorySearcher($searchRootNTDSdsa)
$searcherNTDSdsaRO = New-Object System.DirectoryServices.DirectorySearcher($searchRootNTDSdsa)
$searcherNTDSdsaRW.Filter = "(objectCategory=NTDSDSA)"
$searcherNTDSdsaRO.Filter = "(objectCategory=NTDSDSARO)"
$objNTDSdsaRW = $searcherNTDSdsaRW.FindAll()
$objNTDSdsaRO = $searcherNTDSdsaRO.FindAll()
$TableOfRWDCsInADForest = @()
$objNTDSdsaRW | %{
	$ntdsDN = $_.Properties.distinguishedname
	$nbtRWDCName = $ntdsDN[0].Substring(("CN=NTDS Settings,CN=").Length)
	$nbtRWDCName = $nbtRWDCName.Substring(0,$nbtRWDCName.IndexOf(","))
	$nbtRWDCSite = $ntdsDN[0].Substring(("CN=NTDS Settings,CN=$nbtRWDCName,CN=Servers,CN=").Length)
	$nbtRWDCSite = $nbtRWDCSite.Substring(0,$nbtRWDCSite.IndexOf(","))
	$TableOfRWDCsInADForestObj = "" | Select "DS Name","Site Name"
	$TableOfRWDCsInADForestObj."DS Name" = $nbtRWDCName
	$TableOfRWDCsInADForestObj."Site Name" = $nbtRWDCSite
	$TableOfRWDCsInADForest += $TableOfRWDCsInADForestObj
}
$TableOfRODCsInADForest = @()
$objNTDSdsaRO | %{
	$ntdsDN = $_.Properties.distinguishedname
	$nbtRODCName = $ntdsDN[0].Substring(("CN=NTDS Settings,CN=").Length)
	$nbtRODCName = $nbtRODCName.Substring(0,$nbtRODCName.IndexOf(","))
	$nbtRODCSite = $ntdsDN[0].Substring(("CN=NTDS Settings,CN=$nbtRODCName,CN=Servers,CN=").Length)
	$nbtRODCSite = $nbtRODCSite.Substring(0,$nbtRODCSite.IndexOf(","))
	$TableOfRODCsInADForestObj = "" | Select "DS Name","Site Name"
	$TableOfRODCsInADForestObj."DS Name" = $nbtRODCName
	$TableOfRODCsInADForestObj."Site Name" = $nbtRODCSite
	$TableOfRODCsInADForest += $TableOfRODCsInADForestObj
}
$TableOfDCsInADForest = $TableOfRWDCsInADForest + $TableOfRODCsInADForest


#################################################################
## Get List Of DCs In AD Domain, Create And Present In A Table ##
#################################################################
$contextADDomainToWriteTo = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain",$ADDomainToWriteTo)
$ListOfDCsInADDomain = [System.DirectoryServices.ActiveDirectory.DomainController]::findall($contextADDomainToWriteTo)
$ListOfRWDCsInADDomain = $ListOfDCsInADDomain | ?{$_.InboundConnections -ne $null -and !($_.InboundConnections -match "RODC Connection")}
$ListOfRODCsInADDomain = $ListOfDCsInADDomain | ?{$_.InboundConnections -match "RODC Connection"}
$TableOfDCsInADDomain = @()
$logOutput += "LIST OF DCs IN THE AD DOMAIN $ADDomainToWriteTo.`r`n"
ForEach ($DC in $ListOfDCsInADDomain) {
	$TableOfDCsInADDomainObj = "" | Select Name,PDC,"Site Name","DS Type","IP Address","OS Version"
	$TableOfDCsInADDomainObj.Name = $DC.Name
	$TableOfDCsInADDomainObj.PDC = "FALSE"
	If ($DC.Roles -ne $null -And $DC.Roles -Contains "PdcRole") {
		$TableOfDCsInADDomainObj.PDC = "TRUE"
		$pdcFQDN = $DC.Name
		$pdcSite = $DC.SiteName
	}
	If ( $DC.SiteName -ne $null -And  $DC.SiteName -ne "") {
		$TableOfDCsInADDomainObj."Site Name" = $DC.SiteName
	} Else {
		If (($TableOfDCsInADForest | ?{$_."DS Name" -eq $($($DC.Name).Substring(0,$($DC.Name).IndexOf(".")))} | Measure-Object).Count -eq 1) {
			$TableOfDCsInADDomainObj."Site Name" = ($TableOfDCsInADForest | ?{$_."DS Name" -eq $($($DC.Name).Substring(0,$($DC.Name).IndexOf(".")))})."Site Name"
		}
		If (($TableOfDCsInADForest | ?{$_."DS Name" -eq $($($DC.Name).Substring(0,$($DC.Name).IndexOf(".")))} | Measure-Object).Count -eq 0) {
			$TableOfDCsInADDomainObj."Site Name" = "<Fail>"
		}
		If (($TableOfDCsInADForest | ?{$_."DS Name" -eq $($($DC.Name).Substring(0,$($DC.Name).IndexOf(".")))} | Measure-Object).Count -gt 1) {
			$TableOfDCsInADDomainObj."Site Name" = "<Fail>"
		}
	}
	$DStype = $null
	If ($DStype -eq $null) {
		ForEach ($RWDC In $ListOfRWDCsInADDomain) {
			If ($RWDC.Name -like $DC.Name) {
				$DStype = "Read/Write"
				BREAK
			}
		}
	}
	If ($DStype -eq $null) {
		ForEach ($RODC In $ListOfRODCsInADDomain) {
			If ($RODC.Name -like $DC.Name) {
				$DStype = "Read-Only"
				BREAK
			}
		}
	}
	If ($DStype -eq $null) {
		$DStype = "<Unknown>"

		If (($TableOfRWDCsInADForest | ?{$_."DS Name" -eq $($($DC.Name).Substring(0,$($DC.Name).IndexOf(".")))} | Measure-Object).Count -eq 1) {
			$DStype = "Read/Write"
		}
		If (($TableOfRODCsInADForest | ?{$_."DS Name" -eq $($($DC.Name).Substring(0,$($DC.Name).IndexOf(".")))} | Measure-Object).Count -eq 1) {
			$DStype = "Read-Only"
		}
	}
	$TableOfDCsInADDomainObj."DS Type" = $DStype
	If ($DC.IPAddress -ne $null -And $DC.IPAddress -ne "") {
		$TableOfDCsInADDomainObj."IP Address" = $DC.IPAddress
	} Else {
		$TableOfDCsInADDomainObj."IP Address" = "<Fail>"
	}
	If ($DC.OSVersion -ne $null -And $DC.OSVersion -ne "") {
		$TableOfDCsInADDomainObj."OS Version" = $DC.OSVersion
	} Else {
		$TableOfDCsInADDomainObj."OS Version" = "<Fail>"
	}
	$TableOfDCsInADDomain += $TableOfDCsInADDomainObj
}
$logOutput += "Found $($ListOfDCsInADDomain.count) DC(s) In AD Domain.`r`n"


#########################################
## Automatically Locate An RWDC To Use ##
#########################################
$SourceRWDCInADDomain = ''
If ($SourceRWDCInADDomain -eq "") {
	## Locate Just ONE DC (This Could Be An RWDC Or RODC)
	$SourceRWDCInADDomainObjectONE = [System.DirectoryServices.ActiveDirectory.DomainController]::findone($contextADDomainToWriteTo)

	## Locate All RWDCs In The AD Domain
	$SourceRWDCInADDomainObjectALL = $ListOfRWDCsInADDomain
	$UseRWDC = $False
	
	## Check If The Single DC Found Is An RWDC Or Not By Checking If It Is In The List Of RWDCs
	ForEach ($RWDC In $SourceRWDCInADDomainObjectALL) {
		If ($RWDC.Name -like $SourceRWDCInADDomainObjectONE.Name) {
			$UseRWDC = $True
		}
	}
	
	## If The Single DC Found Is An RWDC, Then Use That One
	If ($UseRWDC -eq $True) {
		$SourceRWDCInADDomainFQDN = $SourceRWDCInADDomainObjectONE.Name
		$SourceRWDCInADDomainSITE = $SourceRWDCInADDomainObjectONE.SiteName
	}

	## If The Single DC Found Is An RODC, Then Find The RWDC With The PDC FSMO Role And Use That
	If ($UseRWDC -eq $False) {
		$SourceRWDCInADDomainFQDN = $pdcFQDN
		$SourceRWDCInADDomainSITE = $pdcSite
	}	

}

## If A Specific RWDC Was Specified Then Use That One
If ($SourceRWDCInADDomain -ne "" -And $SourceRWDCInADDomain -ne "PDC" -And $SourceRWDCInADDomain -ne "STOP") {
	$contextRWDCToWriteTo = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("DirectoryServer",$SourceRWDCInADDomain)
	$SourceRWDCInADDomainObject = [System.DirectoryServices.ActiveDirectory.DomainController]::GetDomainController($contextRWDCToWriteTo)
	$SourceRWDCInADDomainFQDN = $SourceRWDCInADDomainObject.Name
	$SourceRWDCInADDomainSITE = $SourceRWDCInADDomainObject.SiteName	
}

## Check If The Selected DC Actually Exists In The AD Domain And Its Is An RWDC And NOT An RODC
$RWDCvalidity = $False
ForEach ($DC in $ListOfRWDCsInADDomain) {
	If ($DC.Name -like $SourceRWDCInADDomainFQDN) {
		$RWDCvalidity = $True
	}
}

$logOutput += "Checking Existence And Connectivity Of The Specified RWDC $SourceRWDCInADDomainFQDN In the AD domain $ADDomainToWriteTo.`r`n"
If ($RWDCvalidity -eq $True) {
	$logOutput += "Verified the specified DC $SourceRWDCInADDomainFQDN is an RWDC and it exists in the AD domain $ADDomainToWriteTo!`r`n"
	$smbPort = "445"
	$timeOut = "500"
	$smbConnectionResult = $null
	$fqdnDC = $SourceRWDCInADDomainFQDN
	$smbConnectionResult = PortConnectionCheck $fqdnDC $smbPort $timeOut
	If ($smbConnectionResult -eq "SUCCESS") {
		$logOutput += "The specified RWDC $SourceRWDCInADDomainFQDN is reachable!`r`n"
	}
	If ($smbConnectionResult -eq "ERROR") {
        If ($SourceRWDCInADDomainFQDN -notin $unreachableDCs) {
            [array]$unreachableDCs += $SourceRWDCInADDomainFQDN
        }
		$logOutput += "The Specified RWDC $SourceRWDCInADDomainFQDN Is NOT Reachable!`r`n"
		$logOutput += "Please re-run the script and make sure to use an RWDC that is reachable!`r`n"
		$logOutput += "Aborting script.`r`n"
		Break
	}
}
If ($RWDCvalidity -eq $False) {
	$logOutput += "The specified DC $SourceRWDCInADDomainFQDN either does NOT exist in the AD domain $ADDomainToWriteTo or is NOT and RWDC OR is the only DC in the environment!`r`n"
	$logOutput += "Please re-run the script and provide the FQDN of an RWDC within the AD domain $ADDomainToWriteTo that does exist`r`n"
} Else {
    ##########################################################################################
    ## Determine SYSVOL Replication Mechanism And SYSVOL/NetLogon Location On Sourcing RWDC ##
    ##########################################################################################
    $logOutput += "SYSVOL REPLICATION MECHANISM.`r`n"

    ## Get The Default Naming Context
    $defaultNamingContext = (([ADSI]"LDAP://$SourceRWDCInADDomainFQDN/rootDSE").defaultNamingContext)

    ## Find The Computer Account Of The Sourcing RWDC
    $Searcher = New-Object DirectoryServices.DirectorySearcher
    $Searcher.Filter = "(&(objectClass=computer)(dNSHostName=$SourceRWDCInADDomainFQDN))"
    $Searcher.SearchRoot = "LDAP://" + $SourceRWDCInADDomainFQDN + "/OU=Domain Controllers," + $defaultNamingContext
    ## The following appears NOT to work on W2K3, but it does upper-level OSes
    ## $dcObjectPath = $Searcher.FindAll().Path
    ## The following appears to work on all OSes
    $dcObjectPath = $Searcher.FindAll() | %{$_.Path}


    ############################
    ## Check Replication Type ##
    ############################
    ## Check If An NTFRS Subscriber Object Exists To Determine If NTFRS Is Being Used Instead Of DFS-R
    $SearcherNTFRS = New-Object DirectoryServices.DirectorySearcher
    $SearcherNTFRS.Filter = "(&(objectClass=nTFRSSubscriber)(name=Domain System Volume (SYSVOL share)))"
    $SearcherNTFRS.SearchRoot = $dcObjectPath
    $ntfrsSubscriptionObject = $SearcherNTFRS.FindAll()
    If ($ntfrsSubscriptionObject -ne $null) {
        $logOutput += "SYSVOL replication mechanism being used: NTFRS`r`n"
        $sysvolRepType = 'NTFRS'
        ## Get The Local Root Path For The SYSVOL
        ## The following appears NOT to work on W2K3, but it does upper-level OSes
        ## $sysvolRootPathOnSourcingRWDC = $ntfrsSubscriptionObject.Properties.frsrootpath
        ## The following appears to work on all OSes
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
        ## Get The Local Root Path For The SYSVOL
        ## The following appears NOT to work on W2K3, but it does not upper-level OSes. NOT really needed, because W2K3 does not support DFS-R for SYSVOL!
        ## $sysvolRootPathOnSourcingRWDC = $dfsrSubscriptionObject.Properties."msdfsr-rootpath"
        ## The following appears to work on all OSes
        $sysvolRootPathOnSourcingRWDC = $dfsrSubscriptionObject | %{$_.Properties."msdfsr-rootpath"}
    }

    ##################################
    ## SYSVOL/SMB Replication Tests ##
    ##################################
    ## Determine The UNC Of The Folder To Write The Temp File To
    #$scriptsUNCPathOnSourcingRWDC = "\\" + $SourceRWDCInADDomainFQDN + "\" + $($sysvolRootPathOnSourcingRWDC.Replace(":","$")) + "\Scripts"
    $scriptsUNCPathOnSourcingRWDC = "$sysvolRootPathOnSourcingRWDC\Scripts"

    ## Get List Of DCs In AD Domain To Which The Temp Object Will Replicate, Create And Present In A Table
    $logOutput += "LIST OF DIRECTORY SERVERS THE TEMP OBJECT REPLICATES TO.`r`n"

    ## Put The Selected RWDC Already In the Table [A] Of Directory Servers To Which The Temp Object Will Replicate
    $TableOfDSServersA = @()
    $TableOfDSServersAObj = "" | Select-Object Name,"Site Name",Reachable
    $TableOfDSServersAObj.Name = ("$SourceRWDCInADDomainFQDN").ToUpper()
    $TableOfDSServersAObj."Site Name" = $SourceRWDCInADDomainSITE
    $TableOfDSServersAObj.Reachable = "TRUE"
    $TableOfDSServersA += $TableOfDSServersAObj

    ## Put The Selected RWDC Already In the Table [B] Of Directory Servers Where The Replication Starts
    $TableOfDSServersB = @()
    $TableOfDSServersBObj = "" | Select-Object Name,"Site Name",Time
    $TableOfDSServersBObj.Name = ("$SourceRWDCInADDomainFQDN").ToUpper()
    $TableOfDSServersBObj."Site Name" = $SourceRWDCInADDomainSITE
    $TableOfDSServersBObj.Time = 0.00
    $TableOfDSServersB += $TableOfDSServersBObj

    ## Add All Other Remaining DCs In The Targeted AD Domain To The List Of Directory Servers [A]
    ForEach ($DC In $ListOfDCsInADDomain) {
        If(!($DC.Name -like $SourceRWDCInADDomainFQDN)) {
            $TableOfDSServersAObj = "" | Select-Object Name,"Site Name",Reachable
            $TableOfDSServersAObj.Name = $DC.Name
            If ($DC.SiteName -ne $null -And $DC.SiteName -ne "") {
                $TableOfDSServersAObj."Site Name" = $DC.SiteName
            } Else {
                If (($TableOfDCsInADForest | ?{$_."DS Name" -eq $($($DC.Name).Substring(0,$($DC.Name).IndexOf(".")))} | Measure-Object).Count -eq 1) {
                    $TableOfDSServersAObj."Site Name" = ($TableOfDCsInADForest | ?{$_."DS Name" -eq $($($DC.Name).Substring(0,$($DC.Name).IndexOf(".")))})."Site Name"
                }
                If (($TableOfDCsInADForest | ?{$_."DS Name" -eq $($($DC.Name).Substring(0,$($DC.Name).IndexOf(".")))} | Measure-Object).Count -eq 0) {
                    $TableOfDSServersAObj."Site Name" = "<Fail>"
                }
                If (($TableOfDCsInADForest | ?{$_."DS Name" -eq $($($DC.Name).Substring(0,$($DC.Name).IndexOf(".")))} | Measure-Object).Count -gt 1) {
                    $TableOfDSServersAObj."Site Name" = "<Fail>"
                }
            }
            $smbPort = "445"
            $timeOut = "500"
            $smbConnectionResult = $null
            $fqdnDC = $DC.Name
            $smbConnectionResult = PortConnectionCheck $fqdnDC $smbPort $timeOut
            If ($smbConnectionResult -eq "SUCCESS") {
                $TableOfDSServersAObj.Reachable = "TRUE"
                $smbConnection = 'Success'
            }
            If ($smbConnectionResult -eq "ERROR") {
                $TableOfDSServersAObj.Reachable = "FALSE"
                $logOutput += "Failed the SMB connection to $($DC.Name). This generally means port 445 is NOT open to this server.`r`n"
                $smbConnection = 'Failed'
            }
            $TableOfDSServersA += $TableOfDSServersAObj
        }
    }
    $logOutput += "Found $($TableOfDSServersA.count) Directory Server(s).`r`n"


    ## Create The Temp Object On The Targeted RWDC
    $logOutput += "CREATING TEMP TEXT FILE IN SYSVOL/NETLOGON on $SourceRWDCInADDomainFQDN on domain $ADDomainToWriteTo ($domainNCDN)`r`n"
    $domainNCDN = $defaultNamingContext
    #$tempObjectName = "sysvolReplTempObject" + (Get-Date -f yyyyMMddHHmmss) + ".txt"
    $tempObjectName = "repTest.txt"
    #Set-Content -Value '.!!!TEMP OBJECT TO TEST AD REPLICATION LATENCY!!!.' -Path $($scriptsUNCPathOnSourcingRWDC + "\" + $tempObjectName)
    #".!!!TEMP OBJECT TO TEST AD REPLICATION LATENCY!!!." | Out-File -FilePath $($scriptsUNCPathOnSourcingRWDC + "\" + $tempObjectName)
    $logOutput += "Temp text file $tempObjectName has been create din the NetLogon Share of $SourceRWDCInADDomainFQDN!`r`n"

    ## Go Through The Process Of Checking Each Directory Server To See If The Temp Object Already Has Replicated To It
    $startDateTime = Get-Date
    $logOutput += "Found $($TableOfDSServersA.count) Directory Server(s).`r`n"
    $tries = 10

    $logOutput += "Each DC in the list below must be at least accessible through SMB over TCP (445)`r`n"
    While($continue -and $loops -lt $tries) {
        $loops++
        $oldpos = $host.UI.RawUI.CursorPosition
        Start-Sleep 5
        $replicated = $true
        
        ## For Each Directory Server In The List/Table [A] Perform A Number Of Steps
        ForEach ($DSsrv in $TableOfDSServersA) {
            If ($DSsrv.Name -match $SourceRWDCInADDomainFQDN -and $completedDCs -notmatch $DSsrv.Name) {
                $logOutput += "Attempting to contact $($DSsrv.Name.ToUpper())...`r`n"
                $logOutput += "$($DSsrv.Name.ToUpper()) is reachable.`r`n"
                $logOutput += "Confirmed object $tempObjectName exists in the netlogon share of $($DSsrv.Name.ToUpper())`r`n"
                $completedDCs += $DSsrv.Name
                continue
            }

            ## If The Directory Server Is A DC In The AD Domain, Then Connect Through LDAP (TCP:445)
            If ($DSsrv.Name -notmatch $SourceRWDCInADDomainFQDN -and $completedDCs -notmatch $DSsrv.Name) {
                If ($loop -gt 0) {
                    $logOutput += "Retrying connection to $($DSsrv.Name.ToUpper())...`r`n"
                } Else {
                    $logOutput += "Attempting to contact $($DSsrv.Name.ToUpper())...`r`n"
                }
                $connectionResult = $null
                If ($DSsrv.Reachable -eq "TRUE") {
                    $logOutput += "$($DSsrv.Name.ToUpper()) is reachable.`r`n"
                    $objectPath = "\\" + $($DSsrv.Name) + "\Netlogon\" + $tempObjectName
                    $connectionResult = "SUCCESS"
                }
                If ($DSsrv.Reachable -eq "FALSE") {
                    If ($DSsrv.Name -notin $unreachableDCs) {
                        [array]$unreachableDCs += $DSsrv.Name
                    }
                    $logOutput += "$($DSsrv.Name.ToUpper()) is NOT reachable.`r`n"
                    $connectionResult = "FAILURE"
                    $logOutput += "Failed the SMB connection to $($DC.Name). This generally means port 445 is NOT open to this server.`r`n"
                }
            }
            
            ## If The Connection To The DC Is Successful
            If ($connectionResult -eq "SUCCESS" -and $completedDCs -notmatch $DSsrv.Name) {
                If (Test-Path -Path $objectPath) {
                    ## If The Temp Object Already Exists
                    $logOutput += "Confirmed object $tempObjectName exists in the NetLogon Share of $($DSsrv.Name.ToUpper())`r`n"
                    $completedDCs += $DSsrv.Name
                    If ($sysvolTest -ne 'Failed') {
                        $sysvolTest = 'Success'
                    }
                    If (!($TableOfDSServersB | ?{$_.Name -match $DSsrv.Name})) {
                        $TableOfDSServersBobj = "" | Select-Object Name,"Site Name",Time
                        $TableOfDSServersBobj.Name = $DSsrv.Name
                        $TableOfDSServersBObj."Site Name" = $DSsrv."Site Name"
                        $TableOfDSServersBObj.Time = ("{0:n2}" -f ((Get-Date)-$startDateTime).TotalSeconds)
                        $TableOfDSServersB += $TableOfDSServersBObj
                    }
                } Else {
                    ## If The Temp Object Does Not Yet Exist
                    $logOutput += "Object $tempObjectName does NOT exist yet in the NetLogon Share of $($DSsrv.Name.ToUpper())`r`n"
                    $sysvolTest = 'Failed'
                    $replicated  = $false
                }
            }
            
            ## If The Connection To The DC Is Unsuccessful
            If ($connectionResult -eq "FAILURE") {
                $logOutput += "Unable to connect to $($DSsrv.Name.ToUpper()) and check for the temp object.`r`n"
                If (!($TableOfDSServersB | ?{$_.Name -match $DSsrv.Name})) {
                    $TableOfDSServersBobj = "" | Select-Object Name,"Site Name",Time
                    $TableOfDSServersBobj.Name = $DSsrv.Name
                    $TableOfDSServersBObj."Site Name" = $DSsrv."Site Name"
                    $TableOfDSServersBObj.Time = "<Fail>"
                    $TableOfDSServersB += $TableOfDSServersBObj
                }
            }
        }
        If ($replicated) {
            $continue = $false
        } Else {
            $host.UI.RawUI.CursorPosition = $oldpos
        }
    }

    ## Show The Start Time, The End Time And The Duration Of The Replication
    $endDateTime = Get-Date
    $duration = "{0:n2}" -f ($endDateTime.Subtract($startDateTime).TotalSeconds)
    $logOutput += "Start Time: $(Get-Date $startDateTime -format "yyyy-MM-dd HH:mm:ss")`r`n"
    $logOutput += "End Time: $(Get-Date $endDateTime -format "yyyy-MM-dd HH:mm:ss")`r`n"
    $logOutput += "Duration: $duration Seconds`r`n"

    ## Delete The Temp Object On The RWDC
    If ($cleanupTempObject) {
        $logOutput += "Deleting Temp Text File.`r`n"
        Remove-Item $($scriptsUNCPathOnSourcingRWDC + "\" + $tempObjectName) -Force
        $logOutput += "Temp Text File $tempObjectName Has Been Deleted On The Target RWDC!`r`n"
    }


    #########################
    ## AD Replication Test ##
    #########################
    ## Set acceptable time limit for replication last successful run
    If ($os -like '*2012*' -or $os -like '*2016*' -or $os -like '*2019*') {
        $timeSpan = 2
        ForEach ($dc in $ListOfDCsInADDomain) {
            $dcName = $dc.Name
            $logOutput += "Checking $dcName for general replication status...`r`n"
            $generalReplication = Get-ADReplicationPartnerMetadata -Target $dcName -Scope Server -EA 0
            ForEach ($partner in $generalReplication) {
                $pattern = '(?<=\,)(.*?)(?=\,)'
                $parterName = $partner.Partner 
                $parterName = [regex]::replace((([regex]::match($parterName,$pattern)).value),'CN=','')
                $dcReplicatonSuccess = $partner.LastReplicationSuccess
                $dcFails = $partner.ConsecutiveReplicationFailures
                $lastReplication = $partner.LastReplicationSuccess
                If ($lastReplication -lt ((get-date).addhours(-$timeSpan))) {
                    [array]$allDCFails += "Source: $dcName, Destination: $parterName, $dcFails Concurrent Replication Failures"
                    $logOutput += "$dcName is failing replication to $parterName! Last replication: $dcReplicatonSuccess. Consecutive Failures: $dcFails.`r`n"
                    $failedDCs += $dcName
                    $status = 'Failed'
                } Else {
                    $logOutput += "$dcName is successfully replicating to $parterName! Last replication: $lastReplication`r`n"
                    $status = 'Success'
                }
            }
        }
    } Else {
        $status = 'Unsuported OS'
        $failedDCs = 'Unsupported OS'
        $allDCFails = 'Unsupported OS'
        $logOutput += "$os unsupport for the general replication check`r`n"
    }


    #################################
    ## Check for Synchronized Time ##
    #################################
    ForEach($dc in $ListOfDCsInADDomain) {
        If ($dc -notin $unreachableDCs) {
            Try {
                $w32tm = invoke-command -computername $dc -scriptblock{w32tm /monitor /computers:$dc /nowarn} -EA Stop
                $maxIcmp = $icmp
                $icmp = (($w32tm -like "*ICMP*") -replace "ICMP:","" -replace "ms delay","").Trim()
                If ($maxIcmp -lt $icmp) {
                    $maxIcmp = $icmp
                }
                If ($icmp -le "0") {
                    $logOutput += "Confirmed time synchronisation is functional for $dc. $($icmp)ms variance.`r`n"
                    If ($timeStatus -ne 'Warning' -and $timeStatus -ne 'Failed') {
                        $timeStatus = 'Success'
                    }
                }
                If ($icmp -gt "100000") {
                    $logOutput += "Warning, 2 minutes time difference on $dc`r`n"
                    If ($timeStatus -ne 'Failed') {
                        $timeStatus = 'Warning'
                    }
                }
                If ($icmp -gt "300000") {
                    $logOutput += "Critical. Over 5 minutes time difference on $dc!`r`n"
                    $timeStatus = 'Failed'
                }
            } Catch {
                $timeStatus = 'Error'
                $logOutput += "Encountered an error when trying to check the time sync status.`r`n"
            }
        }
    }
}


############################
## Check AD Recycling Bin ##
############################
$adRecycleBin = (Get-ADOptionalFeature -Filter * | Where-Object {$_.Name -eq 'Recycle Bin Feature'}).EnabledScopes
If (!$adRecycleBin) {
    $adRecyclbeBinEnabled = 'Failed'
    $logOutput += "The AD recycling bin is not enabled!`r`n"
} Else {
    $adRecyclbeBinEnabled = 'Success'
    $logOutput += "Verified the AD recycling bin is enabled.`r`n"
}


##########################
## Check for ShadowCopy ##
##########################
$shadowCopy = Get-WmiObject Win32_ShadowCopy -EA 0 | Sort-Object InstallDate | Select-Object -last 1

If($shadowCopy) {
    $shadowCopyStatus = 'Enabled'
    $latestShadowCopy = $shadowCopy.convertToDateTime(($shadowCopy.InstallDate))
    $logOutput += "Verified Shadowcopy is enabled`r`n"
} Else {
    $shadowCopyStatus = 'Disabled'
    $latestShadowCopy = 'None'
    $logOutput += "Shadowcopy is disabled!`r`n"
}


########################################
## Check Forest level vs SchemaMaster ##
########################################
$forestLevel = (Get-ADForest).ForestMode -replace ('forest','')
$dcOS = $os -replace ('microsoft','') -replace('Server','') -replace('Foundation','') -replace(' ','') -replace('Datacenter','') -replace('Standard','') -replace('Core','') -replace('Essentials','') -replace('Small Business','')
If ($forestLevel -eq $dcOS) {
    $forestTest = 'Success'
    $logOutput += "Confirmed the domain functional level matches the OS!`r`n"
} Else {
    $forestTest = 'Failed'
    $logOutput += "The domain functional level is lower than the OS and needs to be upgraded!`r`n"
}
$forestLevel = "Forest: $forestLevel DC OS: $dcOS"


###########################
## Clean up final output ##
###########################
If (!$unreachableDCs) {
    $unreachableDCs = 'None'
}
If (!$allDCFails) {
    $allDCFails = 'None'
}
If (!$failedDCs) {
    $failedDCs = 'None'
}

## Append errors to the total log output
$logOutput += $Error

## Notate fixes per issue found
If ($smbConnection -eq 'Failed') {
    $fixLog += "::ISSUE:: SMB connection has failed: This means $env:COMPUTERNAME was unable to access the SYSVOL share for some or all of the domain controllers in your AD environment.`r`n"
}
If ($sysvolTest -eq 'Failed') {
    $fixLog += "::ISSUE:: SYSVOL replication test has failed: The script that tested this functionality created a test text file in \\$env:COMPUTERNAME\SYSVOL\, then tested to see if the other domain controllers had this file in their \\dcname\SYSVOL\ share. This allows about 5min for the replication to occure and if the file never appears on other DCs, this status is set to failed.`r`n"
}
If ($status -eq 'Failed') {
    $fixLog += "::ISSUE:: Get-ADReplicationPartnerMetadata command has failed: The that tested this functionality has tried to run the Get-ADReplicationPartnerMetadata command from source $env:COMPUTERNAME to each DC in AD. If it reports any failures, this status is set to Failed. This means you have replcation issues on your domain controller(s). Error details: $generalRepFailDetails.`r`n"
}
If ($adRecyclbeBinEnabled -eq 'Failed') {
    $fixLog += "::ISSUE:: AD Recycling Bin is not enabled: The AD recycling bin allows you to quickly restore deleted objects without the need of a system state or 3rd party backup. The recycle bin feature preserves all link valued and non link valued attributes. This means that a restored object will retain all it's settings when restored.`r`n"
}
If ($timeStatus -eq 'Failed') {
    $fixLog += "::ISSUE:: Time sync failures: If the time is off between DCs, this can cause authentication issues, replication issues, and many other issues. See a good breakdown of reasons time sync matters here: https://docs.microsoft.com/en-us/archive/blogs/nepapfe/its-simple-time-configuration-in-active-directory.`r`n"
}
If ($shadowCopyStatus -eq 'Failed') {
    $fixLog += "::ISSUE:: Shadowcopy is not enabled: While shadow copy isn't the gold standard for data recovery/revisioning, it's an easy piece of the backup/restore puzzle to enable so that's why this is flagged. No downside, turn it on.`r`n"
}
If ($forestTest -eq 'Failed') {
    $fixLog += "::ISSUE:: The domain forest functional level is lower than the DC OS: Upgraded domain functionality levels incorporate new features that can only be taken advantage of when all domain controllers in either the domain or forest have been upgraded to the same version.`r`n"
}

"errors=$errorsOut|sysvolSmbConnection=$smbConnection|sysvolRepType=$sysvolRepType|sysvolRepTest=$sysvolTest|sysvolFileRepTime=$duration|unreachableDCs=$unreachableDCs|generalReplicationStatus=$status|generalRepFailDetails=$allDCFails|generalRepFailedDCs=$failedDCs|adRecycleBinEnabled=$adRecyclbeBinEnabled|timeSyncStatus=$timeStatus|maxTimeSyncVariance=$maxIcmp|shadowCopyStatus=$shadowCopyStatus|latestShadowCopy=$latestShadowCopy|forestTest=$forestTest|forestLevel=$forestLevel|logOutput=$logOutput|fixLog=$fixLog"

## For testing
$status = $null
$allDCFails = $null
$failedDCs = $null
$logOutput = $null
$loops = $null
$unreachableDCs = $null
$completedDCs = $null
$fixLog = $null
$forestLevel = $null