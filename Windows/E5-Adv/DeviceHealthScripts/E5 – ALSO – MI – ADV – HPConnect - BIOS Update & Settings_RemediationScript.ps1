$global:EventDetails = New-Object -TypeName PsObject -Property @{
  DT = $null
 "1" = $null
 "2" = $null
 "3" = $null
 "4" = $null
 "5" = $null
 "6" = $null
 "7" = $null
 "8" = $null
 "9" = $null
 "10" = $null
 "11" = $null
 "12" = $null
 "13" = $null
 "14" = $null
 "15" = $null
 "16" = $null
 "17" = $null
 "18" = $null
 "19" = $null
 "20" = $null
 "21" = $null
 "22" = $null
 "23" = $null
}
$freezeStartDate = ""
$freezeEndDate = ""
$throw = $false

function ClientRemediation {
    Param([string]$exception)
   	if($exception -ne "")
	{
		$ReturnCode = "1"
		$ReturnCodeDescription = 'Failure due to: '+ $exception
		Out-File $logFile -Append -InputObject $ReturnCodeDescription
	}  
   
	$Bios_Authentication_Remediation_Event ="BIOS_Authentication_Remediation_Script"
	$Bios_Update_Remediation_Event="BIOS_Update_Remediation_Script"
	$Generic_Remediation_Event_Name ="Generic_Remediation_Script"
	$Prerequisites_Remediation_Event = "Prerequisites_Remediation_Script"
	$ActiveFreeze_Remediation_Event = "FreezeRules_Remediation_Script"
	$Bios_Setting_Remediation_Event ="BIOS_Setting_Remediation_Script"
	switch($Remediation)
	{
	"BiosAuthenticationRemediation"
	{
		#add BIOS Authentication event :

		$BiosAuth = $global:EventDetails.PsObject.Copy()
		$BiosAuth."11" = $Bios_Authentication_Remediation_Event
		$BiosAuth."12" = $null
		$BiosAuth."13" = $null
		$BiosAuth."16" = "1"
		$BiosAuth."17" = $ReturnCodeDescription
		$Events = @(@{ "22.1" = $BiosAuth })
		Out-File $logFile -Append -InputObject "Bios Authentication Remediation Failure"
		Post_Analytics
	}
	"BiosSettingsRemediation"
	{
		$BiosSetting = $global:EventDetails.PsObject.Copy()

		#add BIOS Settings event :
		$BiosSetting."11" = $Bios_Setting_Remediation_Event
		$BiosSetting."16" = "1"
		$BiosSetting."17" = $ReturnCodeDescription
		$Events = @(@{ "22.1" = $BiosSetting})
		Out-File $logFile -Append -InputObject "Bios Setting Remediation Failure"
		Post_Analytics
	}
	"BiosUpdatesRemediation"
	{
		$BiosUpdate = $global:EventDetails.PsObject.Copy()

		#add BIOS Update event :
		$BiosUpdate."11" = $Bios_Update_Remediation_Event
		$BiosUpdate."12" = $null
		$BiosUpdate."13" = $null
		$BiosUpdate."16" = "1"
		$BiosUpdate."17" = $ReturnCodeDescription
		$Events = @(@{ "22.1" = $BiosUpdate})
		Out-File $logFile -Append -InputObject "Bios Update Remediation Failure"
		Post_Analytics
	}
	"AllPoliciesCompleted"
	{

		$BiosAuth = $global:EventDetails.PsObject.Copy()
		#add BIOS Authentication event :
		$BiosAuth."11" = $Bios_Authentication_Remediation_Event
		$BiosAuth."12" = $null
		$BiosAuth."13" = $null
		$BiosAuth."16" = "0"
		$BiosAuth."17" = "BIOS Authentication policy remediation completed"

		$BiosSetting = $global:EventDetails.PsObject.Copy()
		#add BIOS Settings event :
		$BiosSetting."11" = $Bios_Setting_Remediation_Event
		$BiosSetting."16" ="0"
		$BiosSetting."17" = "BIOS Setting policy remediation completed"

		$BiosUpdate = $global:EventDetails.PsObject.Copy()
		#add BIOS Update event :
		$BiosUpdate."11" = $Bios_Update_Remediation_Event
		$BiosUpdate."12" = $null
		$BiosUpdate."13" = $null
		$BiosUpdate."16" = "0"
		$BiosUpdate."17" = "BIOS Update policy remediation completed"

		$Events = @{ "22.1" = $BiosAuth }, @{ "22.1" = $BiosSetting } 	, @{ "22.1" = $BiosUpdate}
		Post_Analytics
	}
	"PreRequisitesRemediation"
	{
		$global:EventDetails."11" = $Prerequisites_Remediation_Event
		Out-File $logFile -Append -InputObject "Failed at Pre Requisite Remediation"
	}
	"ClientDetailsRemediation"
	{
		Out-File $logFile -Append -InputObject "Failed at Client details remediation"
	}
	"FreezeRulesRemediation"
	{
		$ReturnCodeDescription = "Active Freeze Rules in Remediation"
		 $freezeStartDate = $freezeStartDate.ToUniversalTime().ToString('yyyy-MM-dd')
		if($freezeEndDate)
		{
			$freezeEndDate = $freezeEndDate.ToUniversalTime().ToString('yyyy-MM-dd')
		}
		$global:EventDetails."11" = $ActiveFreeze_Remediation_Event
		$global:EventDetails."16" = "0"
		$global:EventDetails."17" =$ReturnCodeDescription
		$global:EventDetails."14" = $freezeStartDate
		$global:EventDetails."15" = $freezeEndDate
		$Events = @(@{ "22.1" = $global:EventDetails })
		Out-File $logFile -Append -InputObject "Active freeze rules in Remediation Before posting analytics"
		Post_Analytics
	}
	Default 
	{
		$global:EventDetails."11" = $Generic_Remediation_Event_Name
		$global:EventDetails."16" = "1"
		$global:EventDetails."17" = $ReturnCodeDescription
		$Events =@(@{ "22.1" = $global:EventDetails })
		Out-File $logFile -Append -InputObject "Default Remediation Failure Before posting analytics"
		Post_Analytics
	}
	}
	
}

$needReboot = $false # This value may be modified in the authentication policy
$enableSureAdmin = $false # This value may be modified in the authentication policy
$logFolder = "$($Env:LocalAppData)\HPConnect\Logs"
$logFile = "6ff9a673-2999-4eef-a49e-56937f6e6d65.log"
$logPathDir = [System.IO.Path]::GetDirectoryName($logFolder)
$exception = ""
$biosSettingsErrorList = @{}
 enum PolicyRemediation
    {
            FreezeRulesRemediation
            PreRequisitesRemediation
            BiosAuthenticationRemediation
            BiosSettingsRemediation
            BiosUpdatesRemediation
            ClientDetailsRemediation
            AllPoliciesCompleted
    }   
    
try
{  
  if ((Test-Path $logPathDir) -eq $false) {
    New-Item -ItemType Directory -Force -Path $logPathDir | Out-Null
  }
  if ((Test-Path -Path $logFolder) -eq $false) {
    New-Item -ItemType directory -Force -Path $logFolder | Out-Null
  }
  $date = Get-Date
  $logFile = $logFolder + "\" +  $logFile
  Out-File $logFile -Append -InputObject "====================== Remediation Script ======================"
  Out-File $logFile -Append -InputObject $date
  Out-File $logFile -Append -InputObject ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
  Out-File $logFile -Append -InputObject $PSVersionTable 

  
   [PolicyRemediation]$Remediation =[PolicyRemediation]::PreRequisitesRemediation
  # Pre-requisites, i.e: HP-CMSL instalation
  function Get-LastestCMSLFromCatalog {
    Param([string]$catalog)

    $json = $catalog | ConvertFrom-Json
    $filter = $json."hp-cmsl" | Where-Object { $_.isLatest -eq $true }
    $sort = @($filter | Sort-Object -Descending {$_.version -As [version]})
    if (-not $sort[0].PSObject.Properties["isLocalLocked"]) {
        Add-Member -InputObject $sort[0] -Name 'isLocalLocked' -Type NoteProperty -Value $false
    }
    $sort[0]
}

# URI to get last HP-CMSL version approved for HP Connect
$preReqUri = 'https://hpia.hpcloud.hp.com/downloads/cmsl/wl/hp-mem-client-prereq.json'
$localDir = "$($Env:LocalAppData)\HPConnect\Tools"
$sharedTools = "$($Env:ProgramFiles)\HPConnect"
$maxTries = 3
$triesInterval = 10

# Download CMSL to the new location
$updateSharedToolsLocation = $false
if ([System.IO.Directory]::Exists("$localDir\hp-cmsl-wl")) {
    if (-not [System.IO.Directory]::Exists("$sharedTools\hp-cmsl-wl")) {
        Out-File $logFile -Append -InputObject "Moving HP-CMSL tool to Program Files"
        $updateSharedToolsLocation = $true
    }
}

# Read local metadata
$localCatalog = "$localDir\hp-mem-client-prereq.json"
$isLocalLocked = $false
$new = $false
if ([System.IO.File]::Exists($localCatalog) -and [System.IO.Directory]::Exists("$sharedTools\hp-cmsl-wl")) {
    $local = Get-LastestCMSLFromCatalog(Get-Content -Path $localCatalog)
    $isLocalLocked = $local.isLocalLocked -eq $true
    Out-File $logFile -Append -InputObject "Current version of HP-CMSL-WL is $($local.version)"
}
else {
    $new = $true
    New-Item -ItemType Directory -Force -Path $localDir | Out-Null
    New-Item -ItemType Directory -Force -Path $sharedTools | Out-Null
}

if (-not $isLocalLocked) {
    $continueWithCurrent = $false
    # Download remote metadata
    $userAgent = "hpconnect-script"
    # Removing obsolete protocols SSL 3.0, TLS 1.0 and TLS 1.1
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]([System.Net.SecurityProtocolType].GetEnumNames() | Where-Object { $_ -ne "Ssl3" -and $_ -ne "Tls" -and $_ -ne "Tls11" })
    $tries = 0
    while ($tries -lt $maxTries) {
        try {
            $data = Invoke-WebRequest -Uri $preReqUri -UserAgent $userAgent -UseBasicParsing -ErrorAction Stop -Verbose 4>> $logFile
            break
        }
        catch {
            Out-File $logFile -Append -InputObject "Failed to retrieve HP-CMSL-WL catalog ($($tries+1)/$maxTries) : $($_.Exception.Message)"
            if ($tries -lt $maxTries-1) {
                if ($tries -lt $maxTries-1) {
                    # Wait some interval between tries
                    Start-Sleep -Seconds $triesInterval
                }
            }
            else {
                if ($new -and -not $updateSharedToolsLocation) {
                    throw "Unable to retrieve HP-CMSL-WL catalog"
                }
                else {
                    Out-File $logFile -Append -InputObject "Unable to retrieve HP-CMSL-WL catalog. The script will continue with the local version"
                    $continueWithCurrent = $true
                }
            }
        }
        $tries = $tries + 1
    }

    if (-not $continueWithCurrent) {
        $catalog = [System.IO.StreamReader]::new($data.RawContentStream).ReadToEnd()
        $remote = Get-LastestCMSLFromCatalog($catalog)
        
        if ($new -or [Version] $remote.version -gt [Version] $local.version) {
            # Download and unpack new version
            $tmpDir = "$env:TEMP"
            $tmpFile = "$tmpDir\hp-cmsl.exe"
            Remove-Item -Path $tmpFile -Force -ErrorAction Ignore
            $tries = 0
            Out-File $logFile -Append -InputObject "Download HP-CMSL-WL $($remote.version) from $($remote.url)"
            while ($tries -lt $maxTries) {
                try {
                    Invoke-WebRequest -Uri $remote.url -UserAgent $userAgent -UseBasicParsing -ErrorAction Stop -OutFile $tmpFile -Verbose 4>> $logFile
                    break
                }
                catch {
                    Out-File $logFile -Append -InputObject "Failed to retrieve HP-CMSL-WL installer ($($tries+1)/$maxTries) : $($_.Exception.Message)"
                    if ($tries -lt $maxTries-1) {
                        if ($tries -lt $maxTries-1) {
                            # Wait some interval between tries
                            Start-Sleep -Seconds $triesInterval
                        }
                    }
                    else {
                        if ($new -and -not $updateSharedToolsLocation) {
                            throw "Unable to download the HP-CMSL-WL installer"
                        }
                        else {
                            Out-File $logFile -Append -InputObject "Unable to download the HP-CMSL-WL installer. The script will continue with the local version"
                            $continueWithCurrent = $true
                        }
                    }
                }
                $tries = $tries + 1
            }

            if (-not $continueWithCurrent) {
                if (-not $new -and -not $updateSharedToolsLocation) {
                    Out-File $logFile -Append -InputObject "Remove current HP-CMSL-WL $($local.version) from $sharedTools\hp-cmsl-wl"
                    Remove-Item -Force -Path "$sharedTools\hp-cmsl-wl" -Recurse
                }
        
                if ($updateSharedToolsLocation) {
                    Out-File $logFile -Append -InputObject "Remove HP-CMSL from previous location $localDir\hp-cmsl-wl"
                    Remove-Item -Force -Path "$localDir\hp-cmsl-wl" -Recurse
                }
        
                Out-File $logFile -Append -InputObject "Unpack CMSL from $tmpFile to $sharedTools\hp-cmsl-wl"
                # Wait for the CMSL extraction to complete
                $arguments = '/LOG="', $tmpDir, '\hp-cmsl-wl.log" /VERYSILENT /SP- /NORESTART /UnpackOnly="True" /DestDir="', $sharedTools, '\hp-cmsl-wl"' -Join ''
                Start-Process -Wait -LoadUserProfile -FilePath $tmpFile -ArgumentList $arguments
                Move-Item -Path "$tmpDir\hp-cmsl-wl.log" -Destination "$logFolder\hp-connect-cmsl.log" -Force -ErrorAction Stop
        
                # Update local metadata
                $catalog | Set-Content -Path $localCatalog -Force
        
                # Delete installer
                Remove-Item -Path $tmpFile -Force -ErrorAction Ignore
            }
        }
    }

    if ($continueWithCurrent) {
        if ($updateSharedToolsLocation) {
            $sharedTools = $localDir
        }
    }
}
else {
    Out-File $logFile -Append -InputObject "Using a local locked version of HP-CMSL-WL"
}

# Import CMSL modules from local folder
Out-File $logFile -Append -InputObject "Import CMSL from $sharedTools\hp-cmsl-wl"
$modules = @(
    'HP.Private',
    'HP.Utility',
    'HP.ClientManagement',
    'HP.Firmware',
    'HP.Notifications',
    'HP.Retail',
    'HP.Softpaq',
    'HP.Sinks',
    'HP.Repo',
    'HP.Consent',
    'HP.SmartExperiences'
)
foreach ($m in $modules) {
    if (Get-Module -Name $m) { Remove-Module -Force $m }
}
foreach ($m in $modules) {
    try {
        Import-Module -Force "$sharedTools\hp-cmsl-wl\modules\$m\$m.psd1" -ErrorAction Stop
    }
    catch {
        $exception = $_.Exception
        Out-File $logFile -Append -InputObject "Failed to import module $m"
        # Script will try to download and import CMSL again on the next execution
        Remove-Item "$sharedTools\hp-cmsl-wl" -Recurse -Force -ErrorAction Stop
        Remove-Item "$localCatalog" -Force -ErrorAction Stop
        throw $exception
    }
}
  
  #Gather client device details for Posting Analytics
  [PolicyRemediation]$Remediation =[PolicyRemediation]::ClientDetailsRemediation
  	# function for compression
	function Compress-Data 
	{
		<#
		.Synopsis
			Compresses data
		.Description
			Compresses data into a GZipStream
		.Link
			Expand-Data
		.Link
			http://msdn.microsoft.com/en-us/library/system.io.compression.gzipstream.aspx
		.Example
			$rawData = (Get-Command | Select-Object -ExpandProperty Name | Out-String)
			$originalSize = $rawData.Length
			$compressed = Compress-Data $rawData -As Byte
			"$($compressed.Length / $originalSize)% Smaller [ Compressed size $($compressed.Length / 1kb)kb : Original Size $($originalSize /1kb)kb] "
			Expand-Data -BinaryData $compressed
		#>
		[OutputType([String],[byte])]
		[CmdletBinding(DefaultParameterSetName='String')]
		param(
		# A string to compress
		[Parameter(ParameterSetName='String',
			Position=0,
			Mandatory=$true,
			ValueFromPipelineByPropertyName=$true)]
		[string]$String,
    
		# A byte array to compress.
		[Parameter(ParameterSetName='Data',
			Position=0,
			Mandatory=$true,
			ValueFromPipelineByPropertyName=$true)]
		[Byte[]]$Data,
    
		# Determine how the data is returned.
		# If set to byte, the data will be returned as a byte array. If set to string, it will be returned as a string.
		[ValidateSet('String','Byte')]
		[String]$As = 'string'   
		)
    
		process {
           
			if ($psCmdlet.ParameterSetName -eq 'String') {
				$Data= foreach ($c in $string.ToCharArray()) {
					$c -as [Byte]
				}            
			}
        
			#region Compress Data
			$ms = New-Object IO.MemoryStream                
			$cs = New-Object System.IO.Compression.GZipStream ($ms, [Io.Compression.CompressionMode]"Compress")
			$cs.Write($Data, 0, $Data.Length)
			$cs.Close()
			#endregion Compress Data
        
			#region Output CompressedData
			if ($as -eq 'Byte') {
				$ms.ToArray()
            
			} elseif ($as -eq 'string') {
				[Convert]::ToBase64String($ms.ToArray())
			}
			$ms.Close()
			#endregion Output CompressedData        
		}
	}
		
	# function to post analytics
	function Post_Analytics {
	# post client analytics 
	try
	{
		$payload = ([PSCustomObject]@{ 
		  hpcunit = $Unit      
		  events =  $Events
		});

		#Adding this for viewing json format of data
		$jsonOutput = $payload | ConvertTo-Json -Depth 5
		$json = $payload | ConvertTo-Json -Depth 5 -Compress
		#Compression Gzip
		$compressed = Compress-Data $json -As Byte
		#Encode the data
		$Base64 = [Convert]::ToBase64String($compressed)
		$partitionKey = [guid]::NewGuid().ToString() + "-w"
		$body =  ([PSCustomObject]@{ 
		  Data = $Base64      
		  PartitionKey =  $partitionKey
		});
		$postdata = $body | ConvertTo-Json -Depth 5;
		Invoke-WebRequest -Uri $clientAnalyticsUrl -UseBasicParsing -Method Put -Body $postdata -ContentType "application/json" | Out-Null		
		Out-File $logFile -Append -InputObject "Successfully posted analytics."
	}
    catch
	{		
		Out-File $logFile -Append -InputObject "Failed to post client analytics : $($_.Exception.Message)"           
	}
	}

	# Params
	$clientAnalyticsUrl ='https://9nki28cu03.execute-api.us-west-2.amazonaws.com/prod/w'	
	$UOID = 'f13bcbf7-cf65-4c63-bf0d-63f8f1da512a'	

   # Prepare OS and device details for posting Client analytics
	$HPCmslInfo = (Get-HPCMSLEnvironment)
	$OSName = if ($HPCmslInfo.psobject.Properties.name -contains "OsName") { $HPCmslInfo.OsName } else { "" }
	$OSBuildNumber = if ($HPCmslInfo.psobject.Properties.name -contains "OsBuildNumber") { $HPCmslInfo.OsBuildNumber } else { "" }
	$OSVersion = if ($HPCmslInfo.psobject.Properties.name -contains "OsVersion") { $HPCmslInfo.OsVersion } else { "" }
	$OSArchitecture = if ($HPCmslInfo.psobject.Properties.name -contains "OSArchitecture") { $HPCmslInfo.OSArchitecture } else { "" }
	$OSDisplayVersion = if ($HPCmslInfo.psobject.Properties.name -contains "OsVer") { $HPCmslInfo.OsVer } else { "" }
	$PowerShellBitness = if ($HPCmslInfo.psobject.Properties.name -contains "Bitness") { $HPCmslInfo.Bitness } else { "" }
	$ProductId = if ($HPCmslInfo.psobject.Properties.name -contains "CsSystemSKUNumber") { $HPCmslInfo.CsSystemSKUNumber } else { "" }
	$SerialNumber = Get-HPDeviceSerialNumber
	$DeviceUUID = Get-HPDeviceUUID
	$CmslVersion =$local.version
	$SMBIOSVersion = Get-HPBIOSSettingValue -Name "System BIOS Version"	
	$PlatformName = Get-HPBIOSSettingValue -Name "Product Name"
	
	# get powershell version
	$PSVersion = if ($HPCmslInfo.psobject.Properties.name -contains "PSVersion") { $HPCmslInfo.PSVersion } else { "" }
	$Major = if ($PSVersion.psobject.Properties.name -contains "Major") { $PSVersion.Major } else { "" }
	$Minor = if ($PSVersion.psobject.Properties.name -contains "Minor") { $PSVersion.Major } else { "" }
	$Build = if ($PSVersion.psobject.Properties.name -contains "Build") { $PSVersion.Major } else { "" }
	$Revision = if ($PSVersion.psobject.Properties.name -contains "Revision") { $PSVersion.Major } else { "" }
	$PowershellVersion = ($Major,$Minor,$Build,$Revision) -Join "."
	
	# Get Unit details 
	$OS = Get-CimInstance -ClassName Win32_OperatingSystem
	$Culture = [System.Globalization.CultureInfo]::GetCultures("SpecificCultures") | Where {$_.LCID -eq $OS.OSLanguage}
	$RegionInfo = New-Object System.Globalization.RegionInfo $Culture.Name
	$CountryCode = $RegionInfo.TwoLetterISORegionName
	$OSLanguage =$OS.OSLanguage
	$OSDetail = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion")
	$OSReleaseId =$OSDetail.ReleaseId
	$UnitModel =Get-HPDeviceModel
	$HPProductID=Get-HPDeviceProductID
	$UnitPlatformID = Get-HPDeviceProductID

	#TODO Confirm below 2 param details :
	$UnitCollectionID =  [guid]::NewGuid()
	$SessionID = [guid]::NewGuid()

	# 2022-04-10T14:59:30-05:00
	$Date = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmss')
	$Version = "1.0"
	$Provider = "HP Connect"
	$ProviderVersion = "v1.0"
	$EventCategory = "Usage"
	$EventType = "Status"	

	$ReturnCodeDescription =""
	$ReturnCode = 0

	# initialize unit
	$Unit =@{
        V =$Version
	    DT= $Date
	    "0" = $SerialNumber
		"1" = $ProductId
	    "2" = $DeviceUUID
	    "3" = $CountryCode
	    "4" = $Provider
	    "5" = $ProviderVersion
	    "6" = $UnitModel
	    "7" = $UnitPlatformID
	    "8" = $UnitCollectionID	
      }	
	
	$global:EventDetails = New-Object -TypeName PsObject -Property @{
	     DT = $Date
		"1" = $UOID
		"2" = $OSVersion
		"3" = $PowershellVersion
		"4" = $CmslVersion
		"5" = $PlatformName
		"6" = $PowerShellBitness
		"7" = $SMBIOSVersion
		"8" = $EventCategory
		"9" = $EventType
		"10" = $Provider
		"11" = ""
		"12" = "N/A"
		"13" = "N/A"
		"14" = $freezeStartDate
		"15" = $freezeEndDate
		"16" = $ReturnCode
		"17" = $ReturnCodeDescription
		"18" = $OSName
		"19" = $OSBuildNumber
		"20" = $OSArchitecture		
		"21" = $OSLanguage
		"22" = $OSDisplayVersion
		"23" = $OSReleaseId
	}	

   [PolicyRemediation]$Remediation =[PolicyRemediation]::FreezeRulesRemediation
  # Process freeze rules (if any)
  
}
catch {
  Out-File $logFile -Append -InputObject "Pre-Requisite failed: $($_.Exception.Message)"
  $exception = $_.Exception.Message
  ClientRemediation -exception $exception
  # If a pre-requisite fails
  throw $_.Exception
}

try {
  # Replace this with combined & ordered remediation scripts from various policy types   
  # Authentication policy script
   [PolicyRemediation]$Remediation =[PolicyRemediation]::BiosAuthenticationRemediation
  

  # BIOS setting policy scripts
  # Skip BIOS setting policy execution if a reboot is needed and the authentication policy is for enabling Sure Admin.
  # When using Sure Admin authentication mode all the setting changes must be signed, so we have to wait for the Secure Platform provisioning process to finish before to apply the setting changes.
  # The Sure Admin is only enabled after the reboot since it requires secure platform provisioning and this is only completed after device reboots.
  if (-not ($needReboot -and $enableSureAdmin)) {
    [PolicyRemediation]$Remediation =[PolicyRemediation]::BiosSettingsRemediation     
    function UpdateBiosSettingsErrors {
    if ($biosSettingsErrorList.Contains($item.Key)) {
        $biosSettingsErrorList[$item.Key] = $errMessage
    }
    else {
        $biosSettingsErrorList.Add($item.Key, $errMessage)
    }
}

function ProcessSureAdminSettings {
    Param(
            $selectedPayload,
            $isFallBackValues
        ) 

        $payload = $selectedPayload[0].Value | ConvertFrom-Json
        $payloadData = [System.Text.Encoding]::ASCII.GetString($payload.Data)
        $settings = $payloadData | ConvertFrom-Json
        # Add settings from generic policy to settings table
        foreach ($s in $settings) {
                $payload.purpose = 'hp:sureadmin:biossetting'
                [SureAdminSetting]$singleSetting = New-Object -TypeName SureAdminSetting
                $singleSetting.Name = $s.Name
                $singleSetting.Value = $s.Value
                $singleSetting.AuthString = $s.AuthString
                $singleStringJson = $singleSetting | ConvertTo-Json
                $payload.data = [System.Text.Encoding]::ASCII.GetBytes($singleStringJson)
                $singleSettingPayload = $payload | ConvertTo-Json -Compress
                if ($isFallBackValues -eq $true) {
                    $key = $s.Name + "_" + $s.Value
                    if ($sureAdminFallbackSettingsTable.Contains($key)) {
                        $sureAdminFallbackSettingsTable[$key] = $singleSettingPayload
                    }
                    else {
                        $sureAdminFallbackSettingsTable.Add($key, $singleSettingPayload)
                    }
                }
                else {
                    # If setting doesn't have PossibleValues attribute go ahead and add it to the dictionary
                    try {
                        $possibleValues = (Get-HPBIOSSetting -Name $s.Name).PossibleValues
                    }
                    catch {
                        $possibleValues = $null
                    }
                    if ($possibleValues -eq $null) {
                        if ($sureAdminSettingsTable.Contains($s.Name)) {
                            $sureAdminSettingsTable[$s.Name] = $singleSettingPayload
                        }
                        else {
                            $sureAdminSettingsTable.Add($s.Name, $singleSettingPayload)
                        }
                    }
                    # If the setting has PossibleValues defined, only add if the value matches to one of the PossibleValues
                    elseif ($possibleValues.Contains($s.Value)) {
                        $logMsg = "Setting $($s.Name) has a possible value variation that matches to $($s.Value)"
                        Out-File $logFile -Append -InputObject $logMsg
                        if ($sureAdminSettingsTable.Contains($s.Name)) {
                            $sureAdminSettingsTable[$s.Name] = $singleSettingPayload
                        }
                        else {
                            $sureAdminSettingsTable.Add($s.Name, $singleSettingPayload)
                        }
                    }
                }
        }
}

$password = ''
$settingsPayloadsTable = @{}

# Array of bios settings hash table
$settingsTable = @{'generic'=@{'Allow Windows Update to manage Slice Module Firmware'='Enable';'Automatic BIOS Update Setting'='Download and install important BIOS updates automatically without prompts';'BIOS Event Logging'='Enable';'Enhanced HP Firmware Runtime Intrusion Prevention and Detection'='Enable';'Configure Legacy Support and Secure Boot'='Legacy Support Disable and Secure Boot Enable';'Legacy Support'='Disable';'Secure Boot'='Enable';};}
$sureadminEnabled = $false
$settingsFallbackTable =[ordered]@{}
$settingsFallbackTable = @{'Allow Windows Update to manage Slice Module Firmware'='';'Automatic BIOS Update Setting'='';'BIOS Event Logging'='';'Enhanced HP Firmware Runtime Intrusion Prevention and Detection'='';'Configure Legacy Support and Secure Boot'='';'Legacy Support'='';'Secure Boot'='';};
$settingsPayloadsFallbackTable = @{}
$biosSettings = @{}
$bitlockerProtectionStatus = (Get-BitLockerVolume | Where-Object VolumeType -EQ "OperatingSystem").ProtectionStatus

# Parse settings from plain settings table
# Get the generic BIOS settings
$selectedGenericRecord = @($settingsTable.GetEnumerator() | Where-Object -Property Name -Match "generic")
if ($selectedGenericRecord.Count -eq 0) {
    Out-File $logFile -Append -InputObject "No generic settings applicable"
}
if ($selectedGenericRecord.Count -gt 1) {
    Out-File $logFile -Append -InputObject "Multiple generic settings entries, using the first"
}
if ($selectedGenericRecord.Count -gt 0) {
    $biosSettings = $selectedGenericRecord[0].Value
    Out-File $logFile -Append -InputObject "Generic BIOS settings selected"
}

$productName = Get-HPBIOSSettingValue -Name "Product Name"
$baseboardId = Get-HPBIOSSettingValue -Name "System Board ID"

# Get the BIOS settings for this specific system ID
$selectedSpecificRecord = @($settingsTable.GetEnumerator() | Where-Object -Property Name -Match "$($baseboardId)\|(.*)")
# Table for Sure Admin Bios settings and Sure Admin Fallback settings
$sureAdminSettingsTable = @{}
$sureAdminFallbackSettingsTable = @{}
if ($selectedSpecificRecord.Count -eq 0) {
    Out-File $logFile -Append -InputObject "No specific settings applicable for platform: $productName, $baseboardId"
}

if ($selectedSpecificRecord.Count -gt 1) {
    Out-File $logFile -Append -InputObject "Multiple entries for the same system id ($baseboardId), using the first one"
}

if ($selectedSpecificRecord.Count -gt 0) {
    $selectedSpecificRecord[0].Value.keys | ForEach-Object {$biosSettings[$_] = $selectedSpecificRecord[0].Value[$_]}
    Out-File $logFile -Append -InputObject "Specific BIOS settings selected"
}

# Parse settings from sure admin payload
if ($sureadminEnabled -eq $true) {
    $selectedGenericPayload = @($settingsPayloadsTable.GetEnumerator() | Where-Object -Property Name -Match "generic")
    if ($selectedGenericPayload.Count -eq 0) {
        Out-File $logFile -Append -InputObject "No generic settings payload applicable"
    }
    if ($selectedGenericPayload.Count -gt 1) {
        Out-File $logFile -Append -InputObject "Multiple generic settings payloads entries, using the first one"
    }
    if ($selectedGenericPayload.Count -gt 0) {
        ProcessSureAdminSettings -selectedPayload $selectedGenericPayload -isFallBackValues $false
    }

    # Parse fallback settings from sure admin fallback payload
    $selectedGenericFallbackPayload = @($settingsPayloadsFallbackTable.GetEnumerator() | Where-Object -Property Name -Match "generic")
    if ($selectedGenericFallbackPayload.Count -eq 0) {
        Out-File $logFile -Append -InputObject "No generic fallback settings payload applicable"
    }
    if ($selectedGenericFallbackPayload.Count -gt 1) {
        Out-File $logFile -Append -InputObject "Multiple generic settings payloads entries, using the first one"
    }
    if ($selectedGenericFallbackPayload.Count -gt 0) {
        ProcessSureAdminSettings -selectedPayload $selectedGenericFallbackPayload -isFallBackValues $true
    }

    # Specific settings parsing
    $selectedSpecificPayload = @($settingsPayloadsTable.GetEnumerator() | Where-Object -Property Name -Match "$($baseboardId)\|(.*)")
    if ($selectedSpecificPayload.Count -eq 0) {
        Out-File $logFile -Append -InputObject "No specific settings payload applicable"
    }
    if ($selectedSpecificPayload.Count -gt 0) {
        # Add/Overwrite settings table with data from specific settings
        ProcessSureAdminSettings -selectedPayload $selectedSpecificPayload -isFallBackValues $false
    }
}

if ($biosSettings.Count -gt 0) {
    $errMessage =""
    $SettingList = Get-WmiObject -Namespace root\HP\InstrumentedBIOS -Class HP_BIOSEnumeration
    foreach ($item in $biossettings.GetEnumerator()) {
        $valueVariationMatch = $false
        try {
            $currentSettingValue = Get-HPBIOSSettingValue -Name $item.Key
            # Test against all value variations
            foreach ($v in $item.Value) {
                if ($item.Key -eq 'UEFI Boot Order') {
                    # Policy contains the complete list of devices including network
                    # In local system we compare only the order of the intersection
                    $v = ((($v) -Split ',') | Where-Object { (($currentSettingValue) -Split ',') -Contains $_ }) -Join ','
                }
                if ($currentSettingValue -eq $v) {
                    $valueVariationMatch = $true
                    break
                }
            }
            # This will be used in the final combined script that gets generated for bios settings/update/etc.
            if (-not $valueVariationMatch) {
                try {
                    $possibleValues = (Get-HPBIOSSetting -Name $item.Key).PossibleValues
                }
                catch {
                    $possibleValues = $null
                }

                foreach ($v in $item.Value) {
                    if ($null -ne $possibleValues -and (-not $possibleValues.Contains($v))) {
                        # Skip if the value is not in the possible values list
                        Out-File $logFile -Append -InputObject "Skipping value $v for setting $($item.Key), not in possible values list"
                        continue;
                    }

                    try{
                        if ($sureadminEnabled -eq $false) {
                            Set-HPBIOSSettingValue -Name $item.Key -Value $v -Password $password *>> $logFile
                            if ($biosSettingsErrorList[$item.Key]) {
                                $biosSettingsErrorList.Remove($item.Key)
                            }
                            $needReboot = $true
                            $valueVariationMatch = $true
                        }
                        else {
                            # Sure Admin is on and at least one setting value variation has to be updated
                            $sureAdminSettingsTable[$item.Key] | Set-HPSecurePlatformPayload *>> $logFile
                            if ($biosSettingsErrorList[$item.Key]) {
                                $biosSettingsErrorList.Remove($item.Key)
                            }
                            $needReboot = $true
                            $valueVariationMatch = $true
                        }

                        # If Secure Boot is being enabled and BitLocker is on, stage a shutdown script to suspend BitLocker if needed
                        if ($needReboot -eq $true -and $valueVariationMatch -eq $true) {
                            if ((($item.Key -eq "Secure Boot" -and $v -eq "Enable") -or
                            ($item.Key -eq "Configure Legacy Support and Secure Boot" -and $v -eq "Legacy Support Disable and Secure Boot Enable")) -and
                            $bitlockerProtectionStatus -ne "Off") {
                                # Stage script to suspend BitLocker if needed on shutdown if Secure Boot is being enabled
                                Out-File $logFile -Append -InputObject "Detected Secure Boot being enabled, adding shutdown script to suspend BitLocker if needed"

                                $scriptsPath = "${env:SystemRoot}\System32\GroupPolicy\Machine"
                                $shutdownScriptName = "wxp_policy_shutdown.ps1"
                                $startupScriptName = "wxp_policy_startup.ps1"
                                $shutdownScriptPath = "$scriptsPath\Scripts\Shutdown\$shutdownScriptName"
                                $startupScriptPath = "$scriptsPath\Scripts\Startup\$startupScriptName"
                                
                                $log = "$logFolder\wxp_policy_shutdown.log"

                                New-Item -ItemType Directory -Force -Path "$scriptsPath\Scripts" | Out-Null
                                New-Item -ItemType Directory -Force -Path "$scriptsPath\Scripts\Startup" | Out-Null
                                New-Item -ItemType Directory -Force -Path "$scriptsPath\Scripts\Shutdown" | Out-Null

                                '$volume = Get-BitLockerVolume | Where-Object VolumeType -EQ "OperatingSystem"
                                if ($volume.ProtectionStatus -ne "Off") {
                                Suspend-BitLocker -MountPoint $volume.MountPoint -RebootCount 1 *>> "' + $log + '"
                                }
                                ' | Out-File $shutdownScriptPath

                                # CMSL modules should be included at startup to use Remove-PSScriptsEntry function
                                $clientManagementModulePath = (Get-Module -Name HP.ClientManagement).Path
                                $privateModulePath = (Get-Module -Name HP.Private).Path

                                # Startup script
                                'Remove-Item -Force "' + $startupScriptPath + '" *>> "' + $log + '"
                                Remove-Item -Force "' + $shutdownScriptPath + '" *>> "' + $log + '"
                                if (Get-Module -Name HP.Private) {remove-module -force HP.Private }
                                if (Get-Module -Name HP.ClientManagement) {remove-module -force HP.ClientManagement }
                                Import-Module -Force "' + $privateModulePath + '" *>> "' + $log + '"
                                Import-Module -Force "' + $clientManagementModulePath + '" *>> "' + $log + '"
                                Remove-PSScriptsEntry -Type "Startup" -CmdLine "' + $startupScriptName + '" *>> "' + $log + '"
                                Remove-PSScriptsEntry -Type "Shutdown" -CmdLine "' + $shutdownScriptName + '" *>> "' + $log + '"
                                gpupdate /wait:0 /force /target:computer *>> "' + $log + '"
                                ' | Out-File $startupScriptPath

                                Remove-PSScriptsEntry -Type "Startup" -CmdLine $startupScriptName | Out-Null
                                Remove-PSScriptsEntry -Type "Shutdown" -CmdLine $shutdownScriptName | Out-Null

                                Add-PSScriptsEntry -Type "Startup" -CmdLine $startupScriptName
                                Add-PSScriptsEntry -Type "Shutdown" -CmdLine $shutdownScriptName
                                
                                $gpt = "${env:SystemRoot}\System32\GroupPolicy\gpt.ini"
                                "[General]`ngPCMachineExtensionNames=[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B6664F-4972-11D1-A7CA-0000F87571E3}]`nVersion=65537" | Set-Content -Path $gpt -Force

                                Out-File $logFile -Append -InputObject "Added startup script to remove wxp_policy_startup.ps1 and wxp_policy_shutdown.ps1"
                            }
                            break # Reboot is required and value variation matched. Exit foreach loop if setting was successfully applied
                        }
                    }
                    catch {
                        $errMessage = "Failed to set BIOS setting: $($item.Key) to desired value variation, $($_.Exception.Message). Possible dependency condition not met."
                        UpdateBiosSettingsErrors
                        Out-File $logFile -Append -InputObject $errMessage
                    }
                }
            }

            # Try to set fallback values if desired value could not set for global policies only.
            if ( -not $valueVariationMatch) {
                if ($settingsFallbackTable[$item.Key]) {
                    $fallbackValueList = [ordered]@{}
                    $fallbackValueList = $settingsFallbackTable[$item.Key]
                    foreach ($v in $fallbackValueList) {
                        if ($v -ne "") {
                            try {
                                if ($sureadminEnabled -eq $false) {
                                    Set-HPBIOSSettingValue -Name $item.Key -Value $v -Password $password *>> $logFile
                                    if ($biosSettingsErrorList[$item.Key]) {
                                        $biosSettingsErrorList.Remove($item.Key)
                                    }
                                    $needReboot = $true
                                    break
                                }
                                else {
                                    # Sure Admin is on and at least one setting value variation has to be updated
                                    $keyName = $item.Key + "_" + $v
                                    $sureAdminFallbackSettingsTable[$keyName] | Set-HPSecurePlatformPayload *>> $logFile
                                    if ($biosSettingsErrorList[$item.Key]) {
                                        $biosSettingsErrorList.Remove($item.Key)
                                    }
                                    $needReboot = $true
                                    break
                                }
                            }
                            catch {
                                $errMessage = "Failed to set BIOS setting: $($item.Key) to fallback value, $($_.Exception.Message). Possible dependency condition not met."
                                UpdateBiosSettingsErrors
                                Out-File $logFile -Append -InputObject $errMessage
                            }
                        }
                        else{
                            Out-File $logFile -Append -InputObject "BIOS setting: $($item.Key) doesnt have any fallback values defined for this setting."
                        }
                    }
                }
                else {
                    Out-File $logFile -Append -InputObject "BIOS setting: $($item.Key) doesnt have any fallback values defined for the setting."
                }
            }
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            # Ignore setting doesn't exist case
            Out-File $logFile -Append -InputObject "Skipping setting that does not exist on this platform: $($item.Key)"
        }
        catch {
            $errMessage = "Failed to set BIOS setting: $($item.Key), $($_.Exception.Message)."
            Out-File $logFile -Append -InputObject $errMessage
            UpdateBiosSettingsErrors
        }
    }
}


    # Log errors without stoping the execution
    if($biosSettingsErrorList.count -gt 0)
    {
        Out-File $logFile -Append -InputObject "BIOS settings exception: Failure for one or more settings" 
        $exception = "BiosSettings Remediation Failure for one or more settings"
        ClientRemediation -exception $exception
    }
  }
}
catch {
  Out-File $logFile -Append -InputObject "BIOS Authentication/Setting exception: $($_.Exception.Message)"
  $exception = $_.Exception.Message
  ClientRemediation($exception)
  $throw = $_.Exception
}

# BIOS update is authentication agnostic, so the scripts run even if an exception was raised in the previous phases, which are Authentication and Setting
try {
  # BIOS update policy scripts
  [PolicyRemediation]$Remediation =[PolicyRemediation]::BiosUpdatesRemediation
      $UpdatesTable = @{'generic' = [pscustomobject]@{UpdateBehavior='Latest';RebootType='Immediately';};}

    
    enum UpdateType {
        WuOnly
        SoftpaqOrWU
        SoftpaqOnly
    }
    
    function Get-BIOSUpdateData {
        param (
            [string]$softpaqUri,
            [string]$vendorName,
            [string]$systemID,
            [string]$biosFamily,
            [string]$targetVersion,
            [string]$logFile 
        )

        $biosUpdateData = $null
        try {
            $srsUri = $softpaqUri + "?vendor=$vendorName&system-id=$systemID&bios-family=$biosFamily"
            $response = Invoke-WebRequest -Uri $srsUri -Method Get -UserAgent $userAgent -UseBasicParsing -ErrorAction Stop -Verbose 4>> $logFile
            if($response.StatusCode -eq 200) {
                if ($response.Content -ne $null -and $response.Content -ne "") {
                    $biosUpdateData = $response.Content | ConvertFrom-Json
                }
                else {
                    Out-File $logFile -Append -InputObject "BIOS update data not available for system ID: $systemID, BIOS family: $biosFamily"
                }                 
            }
            if($response.StatusCode -eq 204) {
                Out-File $logFile -Append -InputObject "BIOS update data not available for system ID: $systemID, BIOS family: $biosFamily"
            }
        }
        catch {
            throw "Error checking for SoftPaq availability: $($_.Exception.Message)"
        }
        
        return $biosUpdateData
    }

    # Possible values of type: Latest, LatestCritical, SpecificVersion
    # For the required type in the policy, get the SoftPaq ID and version.
    # Assuming that the payload is sorted by version in descending order.
    # Assuming the payload structure is as follows:
    # [
    #   {
    #     "version": "01.23.45",
    #     "softpaq": {
    #       "softpaqId": "123456",
    #       "version": "01.23.45",
    #       "releaseType": "critical"
    #     }   
    #   },
    #   ...
    # ]
    function GetSoftPaqId {
        param ([object] $payload ,[string] $type, [string] $version)

        if ($null -eq $payload -or $payload.Count -eq 0) {
            return ($null, $null)
        }
        
        if ($type -eq "SpecificVersion") {
            foreach ($item in $payload) {
                if ($item.version -eq $version) {
                    if ($null -ne $item.softpaq) {
                        return ($item.softpaq.softpaqId, $item.version)
                    }
                    return ($null, $null)
                }
            }
        }
        
        if ($type -eq "Latest") {
            if ($null -ne $payload[0].softpaq) {
                return ($payload[0].softpaq.softpaqId, $payload[0].softpaq.version)
            }
            return ($null, $null)
        }
        
        if ($type -eq "LatestCritical") {
            foreach ($item in $payload) {
                if ($null -ne $item.softpaq -and $item.softpaq.releaseType -eq "critical")
                {
                    return ($item.softpaq.softpaqId, $item.version)
                }
            }
        }
        
        return ($null, $null)
    }

    function CheckUpdateType {
        param ([string] $logFile)
        
        try {
            $biosUpdateCredentialPolicy = Get-HPBIOSSettingValue -Name "BIOS Update Credential Policy"
        } catch {
            $authRequired = Test-HPAuthRequired -BiosUpdateType "Upgrade"
            if ($authRequired -eq $false) {
                Out-File $logFile -Append -InputObject "BIOS Update Credential Policy is not available. No authentication required for BIOS update."
                return [UpdateType]::SoftpaqOrWU
            }

            Out-File $logFile -Append -InputObject "BIOS Update Credential Policy is not available. Authentication required,defaulting to Windows Update only."
            return [UpdateType]::WuOnly
        }

        if ($biosUpdateCredentialPolicy -eq "Always require credentials") {
            throw "Device has BIOS Credential Policy setting with value 'Always require credentials', BIOS update will not be performed as not supported."
        }
        
        return [UpdateType]::SoftpaqOrWU
    }

    function BiosUpdateWithSoftpaq {
        param (
            [object]$updateData,
            [string]$updateBehavior,
            [object]$biosUpdatePolicy,
            [string]$biosFamily,
            [string]$currentVersion,
            [string]$targetVersion,
            [string]$password,
            [string] $softpaqSetupPath,
            [string] $logFile       
        )
        
        $softpaqUpdateInitiated = $false
        $policyCompliant = $false
        ($softpaqId ,$softpaqVersion) = GetSoftPaqId -payload $updateData -type $updateBehavior -version $targetVersion

        if ([string]::IsNullOrEmpty($softpaqId)) {
            Out-File $logFile -Append -InputObject "No SoftPaq found for the specified update behavior: $updateBehavior and target version: $targetVersion"
            return ($softpaqUpdateInitiated, $policyCompliant)
        }
        
        Out-File $logFile -Append -InputObject "Softpaq found for the specified update behavior,SoftPaq ID: $softpaqId, Version: $softpaqVersion"
        $updateRequired = CheckIfBiosUpdateRequired -currentVersion $currentVersion -targetVersion $softpaqVersion
        if ($updateRequired -eq $false) {
            $policyCompliant = $true
            return ($softpaqUpdateInitiated, $policyCompliant)
        }
        
        $targetVersionInfo = $updateBehavior + "_" + $softpaqVersion
        
        #Current BIOS version is less than the target version, initiate the update.
        Out-File $logFile -Append -InputObject "Update the current bios [$($currentVersion)] to $($updateBehavior) [$($softpaqVersion)]"
        try
        {
            $softpaqDownloadPath = $softpaqSetupPath + "sp" + $softpaqId
            Get-Softpaq -Number $softpaqId -Action "silentinstall" -DestinationPath $softpaqDownloadPath | Out-File $logFile -Append
            $softpaqUpdateInitiated = $true
        }
        catch
        {
            throw "$($_.Exception.Message)"
        }
        
        return ($softpaqUpdateInitiated, $policyCompliant)
    }

    function ConvertTo-VersionObject{
        param(
            [Parameter(Mandatory=$true)]
            [string]$VersionString
        )
        # Split the version string by the dot character
        $parts = $VersionString.Split('.') | ForEach-Object { [int]$_ }
        $major = $parts[0]
        $minor = $parts[1]
        # Use 0 if the component doesn't exist in the original string
        $build = if ($parts.Count -gt 2) { $parts[2] } else { 0 }
        $revision = if ($parts.Count -gt 3) { $parts[3] } else { 0 }

        # Reconstruct the string or create the System.Version object
        # Creating a new System.Version object with explicit components handles the padding cleanly.
        return [System.Version]::new($major, $minor, $build, $revision)
    } 
    
    function CheckIfBiosUpdateRequired {
        param (
            [string]$currentVersion,
            [string]$targetVersion
        )

        if ([string]::IsNullOrEmpty($currentVersion) -or [string]::IsNullOrEmpty($targetVersion)) {
            return $false
        }

        $targetVersion = ConvertTo-VersionObject -VersionString $targetVersion
        $currentVersion= ConvertTo-VersionObject -VersionString $currentVersion
        # Compare the versions, not the version strings.
        [System.Version]$targetVersionObject = [System.Version]$targetVersion
        [System.Version]$currentVersionObject = [System.Version]$currentVersion

        if ($currentVersionObject -lt $targetVersionObject) {
            return $true
        }
        return $false
    }
    
    function BiosUpdateWithWU {
        param (
            [string]$updateBehavior,
            [string]$biosFamily,
            [string]$currentVersion,
            [string]$targetVersion,
            [string]$logFile         
        )

        try
        {
            # Possible values of update behavior: Latest, LatestCritical, SpecificVersion
            # For the required update behavior in the policy, get the target BIOS update version.
            if ($updateBehavior -eq "SpecificVersion") {
                $update = Get-HPBIOSWindowsUpdate -Family $biosFamily -Version $targetVersion
            }
            else {
                $update = Get-HPBIOSWindowsUpdate -Family $biosFamily -Severity $updateBehavior
                $targetVersion = $update.Version
            }
        }
        catch
        {
            throw "$($_.Exception.Message)"
        }

        $wuUpdateInitiated = $false
        $policyCompliant = $false
        $updateRequired = CheckIfBiosUpdateRequired -currentVersion $currentVersion -targetVersion $targetVersion
        if ($updateRequired -eq $false) {
            $policyCompliant = $true
            return ($wuUpdateInitiated, $policyCompliant)
        }

        #Current BIOS version is less than the target version, initiate the update.
        $targetVersionInfo = $updateBehavior + "_" + $targetVersion
        Out-File $logFile -Append -InputObject "Update the current bios [$($currentVersion)] to $($updateBehavior) [$($targetVersion)]"
        try
        {
            Get-HPBIOSWindowsUpdate -Flash -Yes -Family $biosFamily -Version $targetVersion | Out-File $logFile -Append
            $wuUpdateInitiated = $true
        }
        catch
        {
            throw "$($_.Exception.Message)"
        }
        
        return ($wuUpdateInitiated, $policyCompliant)
    }
    
    if ([System.String]::IsNullOrEmpty($UpdatesTable)) {
        throw "BIOS update table has not been defined properly"
    }

    $password = ''
    $softpaqUri= "https://www.hpdaas.com/services/srs/api/1.0/bios/updates"
    $softpaqSetupPath = "$($Env:SystemDrive)\SWSetup\"

    # The first parameter above must be replaced with the table containing the BIOS update policy content.
    # The second parameter must be replace with empty string if no password, 
    # and $password = "<password>" if password is provided in the authentication policy.
    # After being replaced, the table definition must have the following format:
    # $UpdatesTable = @{'<systemId>|<biosFamily>]' = [pscustomobject]{'<UpdateBehavior>', '<TargetVersion>', '<Reboot>'}, ... }
    # TODO: Add reboot logic once defined in details.

    # Get the system board ID.
    [string]$systemId = Get-HPBIOSSettingValue -Name "System Board ID"

    # Get the product name.
    [string]$productName = Get-HPBIOSSettingValue -Name "Product Name"

    # Get the lock BIOS version value.
    try {
        [string]$lockBIOSVersion = Get-HPBIOSSettingValue -Name "Lock BIOS Version"
    }
    catch {
        [string]$lockBIOSVersion = 'Disable'
    }
    
    # Get the current BIOS version.
    [string]$biosVersionFull = Get-HPBIOSSettingValue -Name "System BIOS Version"
    [string]$currentVersion = Get-HPBIOSVersion
    $currentVersionInfo = "CurrentVersion_" + $currentVersion    
    $targetVersionInfo = "N/A"

    # Get the BIOS family.
    [string]$biosFamily = $biosVersionFull.Substring(0, 3)

    Out-File $logFile -Append -InputObject "System board ID: $($systemId), BIOS family: $($biosFamily), product name: $($productName)"
    Out-File $logFile -Append -InputObject "Current BIOS version (full): $($biosVersionFull)"
    Out-File $logFile -Append -InputObject "Lock BIOS Version: $($lockBIOSVersion)"

    if ($lockBIOSVersion -match "Enable")
    {
        throw "Lock BIOS Version is set. BIOS update is not allowed."
    }
    
    try
    {
        # Get the details of the BIOS update policy for this system ID and BIOS family.
        $selectedRecord = $UpdatesTable.GetEnumerator() | Where-Object -Property Name -Match "$($systemId)\|(.*)\|$($biosFamily)"

        if ($selectedRecord -eq $null)
        {
           Out-File $logFile -Append -InputObject "BIOS update policy not specified for this platform"
           $selectedRecord = $UpdatesTable.GetEnumerator() | Where-Object { $_.Key -eq "generic" }
               if ($selectedRecord -eq $null) {
            Out-File $logFile -Append -InputObject "Generic BIOS update policy not specified"
           }
        }
    }
    catch
    {
        Out-File $logFile -Append -InputObject "Error in Updates table definition. $($_.Exception.Message) "
        throw "Error in Updates table definition. $($_.Exception.Message) "
    }

    if ($selectedRecord) {
        try
        {
            # The object in the first found record should have the following fields: UpdateBehavior, TargetVersion, Reboot.
            Out-File $logFile -Append -InputObject "Selected BIOS update policy: '$($selectedRecord[0].Key)' = $($selectedRecord[0].Value)"
            $biosUpdatePolicy = $selectedRecord[0].Value

            # If the policy is Latest, check if the current version is the latest.
            $updateBehavior = [string]$biosUpdatePolicy.UpdateBehavior
            
            $targetVersion = [string]$biosUpdatePolicy.TargetVersion
            $targetVersionInfo = $updateBehavior + "_" + $targetVersion
            Out-File $logFile -Append -InputObject "Target Version: $targetVersionInfo"
            
            # Check if BIOS update should be performed using just Windows Update or Just Softpaq or either Softpaq or Windows Update
            $updateType = CheckUpdateType -logFile $logFile

            # Attempt Softpaq update if applicable, else default to Windows Update behavior
            $updateWithWU = $false
            if ($updateType -ne [UpdateType]::WuOnly) {
                # Get BIOS update details from SRS service for the system ID and BIOS family
                $biosUpdateData = Get-BIOSUpdateData -softpaqUri $softpaqUri -vendorName "hp" -systemID $systemId -biosFamily $biosFamily -targetVersion $targetVersion -logFile $logFile
                if ($biosUpdateData -ne $null) {
                    ($result ,$policyCompliant) = BiosUpdateWithSoftpaq -updateData $biosUpdateData -updateBehavior $updateBehavior -biosUpdatePolicy $biosUpdatePolicy -biosFamily $biosFamily -currentVersion $currentVersion -targetVersion $targetVersion -password $password -softpaqSetupPath $softpaqSetupPath -logFile $logFile
                    if($policyCompliant) {
                        Out-File $logFile -Append -InputObject "BIOS update policy is compliant"
                    }
                    elseif (-not $result) {
                        # If Softpaq update is not initiated and policy is SoftpaqOnly, exit
                        if ($updateType -eq [UpdateType]::SoftpaqOnly) {
                            throw "Error in performing Bios update using softpaq only"
                        }
                        Out-File $logFile -Append -InputObject "Softpaq update not initiated, defaulting to Windows Update."
                        $updateWithWU = $true
                    }
                    else
                    {
                        $needReboot = $true
                        Out-File $logFile -Append -InputObject "Softpaq BIOS update initiated for system ID: $systemId, BIOS family: $biosFamily"
                    }
                }
                else {
                    Out-File $logFile -Append -InputObject "Softpaq data not available, defaulting to Windows Update."
                    $updateWithWU = $true
                }
            }
            else {
                $updateWithWU = $true
            }

            if ($updateWithWU) {
                
                try {
                    [string]$isCapsuleUpdateAllowed = Get-HPBIOSSettingValue -Name "Native OS Firmware Update Service"
                }
                catch {
                    [string]$isCapsuleUpdateAllowed = 'Enable'
                }
                
                if ($isCapsuleUpdateAllowed -match "Disable")
                {
                    throw "Native OS Firmware Update Service is disabled. BIOS update is not allowed."
                }
                # If Softpaq update is not applicable or not initiated, perform BIOS update using Windows Update.
                ($result, $policyCompliant) = BiosUpdateWithWU -updateBehavior $updateBehavior -biosFamily $biosFamily -currentVersion $currentVersion -targetVersion $targetVersion -logFile $logFile
                if ($policyCompliant) {
                    Out-File $logFile -Append -InputObject "BIOS update policy is compliant"
                } elseif (-not $result) {
                    throw "Error in performing Bios update using Windows Update"
                } else {
                    $needReboot = $true
                    Out-File $logFile -Append -InputObject "Windows Update BIOS update initiated for system ID: $systemId, BIOS family: $biosFamily"
                }
            }
            
        }
        catch
        {
            throw "Error in Bios update. $($_.Exception.Message)"
        }
        
    }
    else {
        Out-File $logFile -Append -InputObject "BIOS update policy is compliant"
    }

}
catch {
  Out-File $logFile -Append -InputObject "BIOS update exception: $($_.Exception.Message)" 
  $exception = $_.Exception.Message
  ClientRemediation -exception $exception
   # Log exceptions without stoping the execution because a notification may be required from previous phases even if an exception occur on the BIOS update
  $throw = $_.Exception
}

[PolicyRemediation]$Remediation =[PolicyRemediation]::AllPoliciesCompleted
ClientRemediation -exception $exception

if ($needReboot) {
  Out-File $logFile -Append -InputObject "Invoking the toast notification to ask user to reboot"
  gpupdate /wait:0 /force /target:computer | Out-File $logFile -Append
  Invoke-RebootNotification -Title 'PC Reboot Required' -Message 'Your device administrator has applied a policy or update that requires a reboot. Dismiss to apply policy updates on your next PC reboot.'
}

if ($throw) {
  throw $throw
}

 # intune health script , 0 means success 1 means failure    
    if($biosSettingsErrorList.Count -gt 0)
    {      
       $biosSettingsErrorList.GetEnumerator() | ForEach-Object{
        Write-Error "Bios Setting : $($_.key) : Error : $($_.value)"
       }    
       exit 1
    }
    else
    {
        Write-Output ""
        exit 0
    }

