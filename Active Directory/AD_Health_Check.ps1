$logOutput = $null

## Clear The Screen
Clear-Host


## Some Constants
$continue = $true
$cleanupTempObject = $true


## The Function To Test The Port Connection
Function PortConnectionCheck($fqdnDC,$port,$timeOut) {
	$tcpPortSocket = $null
	$portConnect = $null
	$tcpPortWait = $null
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


## Get The FQDN Of The Local AD Domain From The Server This Script Is Executed On
$ADDomainToWriteTo = $(Get-WmiObject -Class Win32_ComputerSystem).Domain


## Get List Of Directory Servers In AD Forest
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


## Get List Of DCs In AD Domain, Create And Present In A Table
$contextADDomainToWriteTo = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain",$ADDomainToWriteTo)
$ListOfDCsInADDomain = [System.DirectoryServices.ActiveDirectory.DomainController]::findall($contextADDomainToWriteTo)
$ListOfRWDCsInADDomain = $ListOfDCsInADDomain | ?{$_.InboundConnections -ne $null -and !($_.InboundConnections -match "RODC Connection")}
$ListOfRODCsInADDomain = $ListOfDCsInADDomain | ?{$_.InboundConnections -match "RODC Connection"}
$TableOfDCsInADDomain = @()
$logOutput += "LIST OF DCs IN THE AD DOMAIN '$ADDomainToWriteTo'.`r`n"
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
$logOutput += "Found [$($ListOfDCsInADDomain.count)] DC(s) In AD Domain.`r`n"


## Specify A RWDC From The Selected AD Domain
$SourceRWDCInADDomain = ''

## If Nothing Was Specified Automatically Locate An RWDC To Use
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

$logOutput += "Checking Existence And Connectivity Of The Specified RWDC '$SourceRWDCInADDomainFQDN' In The AD Domain '$ADDomainToWriteTo'.`r`n"
If ($RWDCvalidity -eq $True) {
	$logOutput += "The Specified DC '$SourceRWDCInADDomainFQDN' Is An RWDC And It Exists In The AD Domain '$ADDomainToWriteTo'!`r`n"
	$logOutput += "Continuing Script.`r`n"
	$smbPort = "445"
	$timeOut = "500"
	$smbConnectionResult = $null
	$fqdnDC = $SourceRWDCInADDomainFQDN
	$smbConnectionResult = PortConnectionCheck $fqdnDC $smbPort $timeOut
	If ($smbConnectionResult -eq "SUCCESS") {
		$logOutput += "The Specified RWDC '$SourceRWDCInADDomainFQDN' Is Reachable!`r`n"
		$logOutput += "Continuing Script.`r`n"
	}
	If ($smbConnectionResult -eq "ERROR") {
		$logOutput += "The Specified RWDC '$SourceRWDCInADDomainFQDN' Is NOT Reachable!`r`n"
		$logOutput += "Please Re-Run The Script And Make Sure To Use An RWDC That Is Reachable!`r`n"
		$logOutput += "Aborting Script.`r`n"
		Break
	}
}
If ($RWDCvalidity -eq $False) {
	$logOutput += "The Specified DC '$SourceRWDCInADDomainFQDN' Either Does NOT Exist In The AD Domain '$ADDomainToWriteTo' Or Is NOT And RWDC!`r`n"
	$logOutput += "Please Re-Run The Script And Provide The FQDN Of An RWDC Within The AD Domain '$ADDomainToWriteTo' That Does Exist`r`n"
	$logOutput += "Aborting Script.`r`n"
	Break
}

## Determine SYSVOL Replication Mechanism And SYSVOL/NetLogon Location On Sourcing RWDC
$logOutput += "SYSVOL REPLICATION MECHANISM.`r`n"

## Get The Default Naming Contexr
$defaultNamingContext = (([ADSI]"LDAP://$SourceRWDCInADDomainFQDN/rootDSE").defaultNamingContext)

## Find The Computer Account Of The Sourcing RWDC
$Searcher = New-Object DirectoryServices.DirectorySearcher
$Searcher.Filter = "(&(objectClass=computer)(dNSHostName=$SourceRWDCInADDomainFQDN))"
$Searcher.SearchRoot = "LDAP://" + $SourceRWDCInADDomainFQDN + "/OU=Domain Controllers," + $defaultNamingContext
## The following appears NOT to work on W2K3, but it does upper-level OSes
## $dcObjectPath = $Searcher.FindAll().Path
## The following appears to work on all OSes
$dcObjectPath = $Searcher.FindAll() | %{$_.Path}

## Check If An NTFRS Subscriber Object Exists To Determine If NTFRS Is Being Used Instead Of DFS-R
$SearcherNTFRS = New-Object DirectoryServices.DirectorySearcher
$SearcherNTFRS.Filter = "(&(objectClass=nTFRSSubscriber)(name=Domain System Volume (SYSVOL share)))"
$SearcherNTFRS.SearchRoot = $dcObjectPath
$ntfrsSubscriptionObject = $SearcherNTFRS.FindAll()
If ($ntfrsSubscriptionObject -ne $null) {
    $logOutput += "SYSVOL Replication Mechanism Being Used.: NTFRS`r`n"
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
    $logOutput += "SYSVOL Replication Mechanism Being Used.: DFS-R`r`n"
    $sysvolRepType = 'DFS-R'
    ## Get The Local Root Path For The SYSVOL
	## The following appears NOT to work on W2K3, but it does not upper-level OSes. NOT really needed, because W2K3 does not support DFS-R for SYSVOL!
    ## $sysvolRootPathOnSourcingRWDC = $dfsrSubscriptionObject.Properties."msdfsr-rootpath"
    ## The following appears to work on all OSes
    $sysvolRootPathOnSourcingRWDC = $dfsrSubscriptionObject | %{$_.Properties."msdfsr-rootpath"}
}

## Determine The UNC Of The Folder To Write The Temp File To
$scriptsUNCPathOnSourcingRWDC = "\\" + $SourceRWDCInADDomainFQDN + "\" + $($sysvolRootPathOnSourcingRWDC.Replace(":","$")) + "\Scripts"


## Get List Of DCs In AD Domain To Which The Temp Object Will Replicate, Create And Present In A Table
$logOutput += "LIST OF DIRECTORY SERVERS THE TEMP OBJECT REPLICATES TO.`r`n"

## Put The Selected RWDC Already In the Table [A] Of Directory Servers To Which The Temp Object Will Replicate
$TableOfDSServersA = @()
$TableOfDSServersAObj = "" | Select Name,"Site Name",Reachable
$TableOfDSServersAObj.Name = ("$SourceRWDCInADDomainFQDN [SOURCE RWDC]").ToUpper()
$TableOfDSServersAObj."Site Name" = $SourceRWDCInADDomainSITE
$TableOfDSServersAObj.Reachable = "TRUE"
$TableOfDSServersA += $TableOfDSServersAObj

## Put The Selected RWDC Already In the Table [B] Of Directory Servers Where The Replication Starts
$TableOfDSServersB = @()
$TableOfDSServersBObj = "" | Select Name,"Site Name",Time
$TableOfDSServersBObj.Name = ("$SourceRWDCInADDomainFQDN [SOURCE RWDC]").ToUpper()
$TableOfDSServersBObj."Site Name" = $SourceRWDCInADDomainSITE
$TableOfDSServersBObj.Time = 0.00
$TableOfDSServersB += $TableOfDSServersBObj

## Add All Other Remaining DCs In The Targeted AD Domain To The List Of Directory Servers [A]
ForEach ($DC In $ListOfDCsInADDomain) {
	If(!($DC.Name -like $SourceRWDCInADDomainFQDN)) {
		$TableOfDSServersAObj = "" | Select Name,"Site Name",Reachable
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
            $smbConnection = 'Failed'
		}
		$TableOfDSServersA += $TableOfDSServersAObj
	}
}
$logOutput += "Found [$($TableOfDSServersA.count)] Directory Server(s).`r`n"


## Create The Temp Object On The Targeted RWDC
$logOutput += "CREATING TEMP TEXT FILE IN SYSVOL/NETLOGON.:"
$domainNCDN = $defaultNamingContext
$tempObjectName = "sysvolReplTempObject" + (Get-Date -f yyyyMMddHHmmss) + ".txt"
$logOutput += "On RWDC...: $SourceRWDCInADDomainFQDN`r`n"
$logOutput += "With Full Name...: $tempObjectName`r`n"
$logOutput += "With Contents...: .!!!TEMP OBJECT TO TEST SYSVOL REPLICATION LATENCY!!!.`r`n"
$logOutput += "In AD Domain...: $ADDomainToWriteTo ($domainNCDN)`r`n"
".!!!TEMP OBJECT TO TEST AD REPLICATION LATENCY!!!." | Out-File -FilePath $($scriptsUNCPathOnSourcingRWDC + "\" + $tempObjectName)
$logOutput += "Temp Text File [$tempObjectName] Has Been Created In The NetLogon Share Of RWDC [$SourceRWDCInADDomainFQDN]!`r`n"


## Go Through The Process Of Checking Each Directory Server To See If The Temp Object Already Has Replicated To It
$startDateTime = Get-Date
$i = 0
$logOutput += "Found [$($TableOfDSServersA.count)] Directory Server(s).`r`n"

While($continue) {
    $i++
    $oldpos = $host.UI.RawUI.CursorPosition
    $logOutput += "Each DC In The List Below Must Be At Least Accessible Through SMB Over TCP (445)`r`n"
    Start-Sleep 1
    $replicated = $true
	
	## For Each Directory Server In The List/Table [A] Perform A Number Of Steps
    ForEach ($DSsrv in $TableOfDSServersA) {
		If ($DSsrv.Name -match $SourceRWDCInADDomainFQDN) {
			$logOutput += "Contacting DC In AD domain .[$($DSsrv.Name.ToUpper())].`r`n"
			$logOutput += "DC Is Reachable.`r`n"
			$logOutput += "Object [$tempObjectName] Exists In The NetLogon Share`r`n"
			continue
		}

		## If The Directory Server Is A DC In The AD Domain, Then Connect Through LDAP (TCP:445)
        If ($DSsrv.Name -notmatch $SourceRWDCInADDomainFQDN) {
			
			$logOutput += "Contacting DC In AD domain .[$($DSsrv.Name.ToUpper())].`r`n"
			$connectionResult = $null
			If ($DSsrv.Reachable -eq "TRUE") {
				$logOutput += "DC Is Reachable.`r`n"
				$objectPath = "\\" + $($DSsrv.Name) + "\Netlogon\" + $tempObjectName
				$connectionResult = "SUCCESS"
			}			
			If ($DSsrv.Reachable -eq "FALSE") {
				$logOutput += "DC Is NOT Reachable.`r`n"
				$connectionResult = "FAILURE"
			}			
		}
		
		## If The Connection To The DC Is Successful
		If ($connectionResult -eq "SUCCESS") {
			If (Test-Path -Path $objectPath) {
				## If The Temp Object Already Exists
                $logOutput += "Object [$tempObjectName] Now Does Exist In The NetLogon Share`r`n"
                If ($sysvolTest -ne 'Failed') {
                    $sysvolTest = 'Success'
                }
				If (!($TableOfDSServersB | ?{$_.Name -match $DSsrv.Name})) {
					$TableOfDSServersBobj = "" | Select Name,"Site Name",Time
					$TableOfDSServersBobj.Name = $DSsrv.Name
					$TableOfDSServersBObj."Site Name" = $DSsrv."Site Name"
					$TableOfDSServersBObj.Time = ("{0:n2}" -f ((Get-Date)-$startDateTime).TotalSeconds)
					$TableOfDSServersB += $TableOfDSServersBObj
				}
			} Else {
				## If The Temp Object Does Not Yet Exist
                $logOutput += "Object [$tempObjectName] Does NOT Exist Yet In The NetLogon Share`r`n"
                $sysvolTest = 'Failed'
				$replicated  = $false
			}
		}
		
		## If The Connection To The DC Is Unsuccessful
		If ($connectionResult -eq "FAILURE") {
			$logOutput += "Unable To Connect To DC/GC And Check For The Temp Object.`r`n"
			If (!($TableOfDSServersB | ?{$_.Name -match $DSsrv.Name})) {
				$TableOfDSServersBobj = "" | Select Name,"Site Name",Time
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
	$logOutput += "Temp Text File [$tempObjectName] Has Been Deleted On The Target RWDC!`r`n"
}

## AD general replication test
## Set acceptable time limit for replication last successful run
$timeSpan = New-TimeSpan -Hours 2

ForEach ($dc in $ListOfDCsInADDomain) {
    $dcName = $dc.Name
    $logOutput += "Checking $dcName for general replication status.`r`n"
    $generalReplication = Get-ADReplicationPartnerMetadata -Target $dcName -Scope Server -EA 0
    $dcReplicatonSuccess = $generalReplication.LastReplicationSuccess
    $dcFails = $generalReplication.ConsecutiveReplicationFailures
    $lastReplication = $generalReplication.LastReplicationSuccess
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

#### Check AD Recycling Bin ####
$adRecycleBin = (Get-ADOptionalFeature -Filter * | Where {$_.Name -eq 'Recycle Bin Feature'}).EnabledScopes
If (!$adRecycleBin) {
    $adRecyclbeBinEnabled = 'Failed'
    $logOutput += "The AD recycling bin is not enabled!`r`n"
} Else {
    $adRecyclbeBinEnabled = 'Success'
    $logOutput += "Verified the AD recycling bin is enabled.`r`n"
}

#### Check for synchronized time ####
ForEach($dc in $ListOfDCsInADDomain){
    $w32tm = invoke-command -computername $dc -scriptblock{w32tm /monitor /computers:$dc /nowarn}
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
}


"sysvolSmbConnection=$smbConnection|sysvolRepType=$sysvolRepType|smbConnection=$smbConnection|sysvolRepTest=$sysvolTest|sysvolFileRepTime=$duration|generalReplicationStatus=$status|generalRepFailDetails=$allDCFails|generalRepFailedDCs=$failedDCs|adRecycleBinEnabled=$adRecyclbeBinEnabled|timeSyncStatus=$timeStatus|maxTimeSyncVariance=$maxIcmp|logOutput=$logOutput"

## For testing
$status = $null
$allDCFails = $null
$failedDCs = $null
$logOutput = $null
