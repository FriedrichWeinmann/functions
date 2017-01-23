function Import-ModuleExchange
{
	<#
		.SYNOPSIS
			Sets up a full connection to any on-premise Exchange Server starting 2010.
		
		.DESCRIPTION
			This function establishes a connection with an Exchange Server, by importing a session from the remote powershell hosted in the IIS service.
			However, this function does not merely do a simple remote session:
			- It uses the locally available Exchange Shell binaries, if present.
			- It copies the binaries from the exchange server it connects to, when a suitable ExchangeShell is not locally installed
			
			This allows it to support full serialization of all objects passing between the remote server and the local powershell console. This in turn makes the session imported using this command a full replica of a regular ExchangeShell session, only with a lot more flexibility.
	
			Running this in full (non-light) mode, without an ExchangeShell of correct major Exchange Version installed requires privileges, when running it for the first time:
			- Read-Access to the installpath of the remote server, to copy binaries.
			- Elevation, to set up the files and registry keys where they belong.
			This also applies when using the -Force parameter, as then - again - the transfer and setup become necessary.
	
			Autodiscover:
			When operating in autodiscover mode (which it does by default), this function will try to find a suitable CAS using Active Directory Queries:
			- It will first check the local site and get the newest one.
			- Failing this it will check the entire forest instead and get the newest one.
		
		.PARAMETER ComputerName
			If this is specified, the connection will be made with this computer. By default, the command uses Autodiscover mechanisms using Active Directory (which will of course fail on a non-joined computer)
		
		.PARAMETER Light
			Rather than doing a full ExchangeShell connection, use a 'light' connection only.
			This causes the function to disregard all libraries and restrict itself to default powershell remoting. Useful in scenarios where you have no management Access to the Windows Server part of the Exchange Server you are accessing.
		
		.PARAMETER Force
			Force will cause the function to delete local binaries before processing full (non-light) mode.
			When using full (non-light) mode, this function will reuse existing binaries, rather than re-transferring them from the server.
			In an environment with multiple versions of Exchange Servers, this can lead to compatibility issues, which is where this switch comes in:
			It will delete the local binaries and then re-download them from the server it is connecting to. It will NOT delete local binaries if a full ExchangeShell installation is detected.
		
		.PARAMETER Credential
			Alternate credentials to use when connecting to Exchange.
		
		.PARAMETER SessionTimeout
			Default: 180000
			The Session timeout of the PowerShell session.
		
		.PARAMETER Authentication
			Default: [System.Management.Automation.Runspaces.AuthenticationMechanism]::Default
			The Authentication mechanism to use when connecting to Exchange.
		
		.PARAMETER ModulePath
			Default: "$($env:APPDATA)\Microsoft\Exchange\RemotePowerShell"
			In order to import the functions properly, the remote session will be exported into a module and then imported using the Import-Module cmdlet (otherwise it would be local scope only).
			This module is stored in a folder named after the server connected to. All those module folders will be stored in a specific path - the path specified in this parameter.
			In most scenarios, it is ok to leave this as it is. However, it may be necessary to specify alternative paths, depending on security settings (e.g.: Software Restriction Lockdown).
		
		.PARAMETER Silent
			This switch replaces the soft, userfriendly yellow warnings with the cold red of unreadable errors.
		
		.EXAMPLE
			PS C:\> Import-ModuleExchange
	
			Loads the fully functional Exchange Cmdlets from an Exchange Server.
			The server connecting to is determined from AD.
	
		.EXAMPLE
			PS C:\> Import-ModuleExchange -Light -ComputerName "srv-exchange01.domain.com" -Credential (Get-Credential)
	
			Opens a remote connection to "srv-exchange01.domain.com", using the credentials specified.
			- This will not result in AD queries
			- This will not use local binaries
			- This will not try to access any paths on the server
			- The only check done before initiating connection, is whether the name can be resolved in DNS
	
		.EXAMPLE
			PS C:\> Import-ModuleExchange -Force
	
			Loads the fully functional Exchange Cmdlets from an Exchange Server.
			The server connecting to is determined from AD.
			Before establishing a connection, this will purge all local files for the Exchange Version of the target server and redownload all binaries.
		
		.NOTES
			Supported Interfaces:
			------------------------
			
			Author:       Friedrich Weinmann
			Company:      die netzwerker Computernetze GmbH
			Created:      16.07.2014
			LastChanged:  14.06.2016
			Version:      2.0
		
		.LINK
			https://ws-40.simplexgate.net/x/DQBx
	#>
	
	[CmdletBinding()]
	Param (
		[string]
		$ComputerName,
		
		[switch]
		$Light,
		
		[switch]
		$Force,
		
		[PSCredential]
		$Credential,
		
		[int]
		$SessionTimeout = 180000,
		
		[System.Management.Automation.Runspaces.AuthenticationMechanism]
		$Authentication = ([System.Management.Automation.Runspaces.AuthenticationMechanism]::Default),
		
		[string]
		$ModulePath = "$($env:APPDATA)\Microsoft\Exchange\RemotePowerShell",
		
		[switch]
		$Silent
	)
	
	#region Utility Functions
	function Connect-ExchangeServer
	{
		[CmdletBinding()]
		Param (
			[string]
			$ComputerName,
			
			[switch]
			$Light,
			
			[PSCredential]
			$Credential,
			
			[int]
			$SessionTimeout,
			
			[System.Management.Automation.Runspaces.AuthenticationMechanism]
			$Authentication,
			
			[string]
			$ModulePath,
			
			[string]
			$ClientVersion,
			
			[string]
			$ClientApplication
		)
		
		#region Build Session
		
		# Prepare connection Uri (Light mode should not use serialization Level)
		$ConnectionUri = "http://$ComputerName/powershell"
		if (-not $Light)
		{
			$ConnectionUri += "?serializationLevel=Full"
			if ($ClientVersion) { $ConnectionUri += ";ExchClientVer=$ClientVersion" }
			if ($ClientApplication) { $ConnectionUri += ";clientApplication=$ClientApplication" }
		}
		
		# Prepare timeout options
		$SessionOptions = New-PSSessionOption -OperationTimeout $SessionTimeout -IdleTimeout $SessionTimeout -OpenTimeout $SessionTimeout
		
		# Open the session
		$splat = @{
			ConnectionUri = $ConnectionUri
			ConfigurationName = "Microsoft.Exchange"
			SessionOption = $SessionOptions
			Authentication = $Authentication
		}
		if ($Credential) { $splat["Credential"] = $Credential }
		$Session = New-PSSession @splat
		
		#endregion Build Session
		
		#region Export / Import Module
		
		# Prepare significant module parameters
		$module_path = Join-Path $ModulePath $ComputerName
		$hashValue = $Session.ApplicationPrivateData.ImplicitRemoting.Hash
		$remotePSSettingsPath = "HKCU:Software\Microsoft\ExchangeServer\v14\RemotePowerShell\$ComputerName"
		
		# Clean up any previous configuration data
		Clear-Item $remotePSSettingsPath -Force -ErrorAction SilentlyContinue
		Get-ChildItem $module_path -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
		
		# Re-Create configuration data
		New-Item $remotePSSettingsPath -force | Out-Null
		New-ItemProperty -Path $remotePSSettingsPath -Name Hash -Value $hashValue -PropertyType DWord -force | Out-Null
		New-ItemProperty -Path $remotePSSettingsPath -Name ModulePath -value $module_path -PropertyType ExpandString -force | Out-Null
		
		# Export the pssession and import it as module
		Export-PSSession -Session $session -OutputModule $module_path -Force | Out-Null
		Import-Module -Name $module_path -ArgumentList $session -DisableNameChecking
		
		#endregion Export / Import Module
	}
	
	function Get-ClosestExchangeServer
	{
		[CmdletBinding()]
		Param (
		
		)
		
		#region Detect Site ($siteDN & $Forest_CurrentSite)
		$localSite = $null
		$localSite = [System.DirectoryServices.ActiveDirectory.ActiveDirectorySite]::GetComputerSite()
		if ($localSite -eq $null)
		{
			# no site - no auto discovery
			throw "Could not detect local site!"
		}
		
		$siteDN = $localSite.GetDirectoryEntry().DistinguishedName
		#Get the Forest name of the current site explicitly, to avoid problem with connecting to wrong LDAP point when logged on to different user domain
		$Forest_CurrentSite = $localSite.Domains[0].Forest.Name
		#endregion Detect Site
		
		#region Get Exchange Servers
		
		# Declare variables to be safe under Windows 7
		$Servers_InSite = @()
		$Servers_Any = @()
		
		# Prepare Query
		$configNC = ([ADSI]"LDAP://$Forest_CurrentSite/RootDse").configurationNamingContext
		$search = new-object DirectoryServices.DirectorySearcher([ADSI]"LDAP://$Forest_CurrentSite/$configNC")
		$search.Filter = "(&(objectClass=msExchExchangeServer)(versionNumber>=1937801568)(msExchServerSite=$siteDN))"
		$search.PageSize = 1000
		$search.PropertiesToLoad.Clear()
		[void]$search.PropertiesToLoad.Add("msexchcurrentserverroles")
		[void]$search.PropertiesToLoad.Add("networkaddress")
		[void]$search.PropertiesToLoad.Add("serialnumber")
		[void]$search.PropertiesToLoad.Add("versionNumber")
		
		# Retrieve CAS Servers in Site
		$Servers_InSite += $search.FindAll() | Where-Object { !($_.properties["msexchcurrentserverroles"][0] -band 4) -eq 0 }
		if ($Servers_InSite.Length -gt 0)
		{
			$list = @()
			foreach ($server in $Servers_InSite) { $list += New-Object System.Management.Automation.PSObject -Property $server.Properties }
			foreach ($entry in $list) { $entry | Add-Member -Name Version -Value $entry.versionnumber[0] -MemberType NoteProperty }
			$Result = $entry | Sort-Object Version | Select-Object -First 1
			return (($Result.networkaddress | Where-Object { $_ -like "ncacn_ip_tcp:*" }) -split ":" | Select-Object -last 1)
		}
		
		# Retrieve CAS Servers anywhere
		$search.Filter = "(&(objectClass=msExchExchangeServer)(versionNumber>=1937801568))"
		$Servers_Any += $search.FindAll() | Where-Object { !($_.properties["msexchcurrentserverroles"][0] -band 4) -eq 0 }
		
		if ($Servers_Any.Length -gt 0)
		{
			$list = @()
			foreach ($server in $Servers_Any) { $list += New-Object System.Management.Automation.PSObject -Property $server.Properties }
			foreach ($entry in $list) { $entry | Add-Member -Name Version -Value $entry.versionnumber[0] -MemberType NoteProperty }
			$Result = $entry | Sort-Object Version | Select-Object -First 1
			return (($Result.networkaddress | Where-Object { $_ -like "ncacn_ip_tcp:*" }) -split ":" | Select-Object -last 1)
		}
		
		#endregion Get Exchange Servers
		
		throw "Failed to find any Exchange Servers!"
	}
	
	function Get-ExchangeInstallPath
	{
		[CmdletBinding()]
		Param (
			[string]
			$ComputerName,
			
			[switch]
			$SmbPath
		)
		
		# Retrieve the Exchange Server to process
		$Forestname = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Name
		
		$configNC = ([ADSI]"LDAP://$Forestname/RootDse").configurationNamingContext
		$search = new-object DirectoryServices.DirectorySearcher([ADSI]"LDAP://$Forestname/$configNC")
		$search.Filter = "(&(objectClass=msExchExchangeServer)(networkaddress=ncacn_ip_tcp:$ComputerName))"
		$search.PageSize = 1000
		$search.PropertiesToLoad.Clear()
		$search.PropertiesToLoad.Add("msexchinstallpath") | Out-Null
		
		# Try to parse the string value of serial number
		$Server = $search.FindOne()
		$line = $Server.Properties["msexchinstallpath"][0]
		
		# Return the path
		if ($SmbPath) { return "\\$ComputerName\$($line.Replace(":", '$'))" }
		else { return $line }
	}
	
	function Get-ExchangeVersion
	{
		[CmdletBinding()]
		Param (
			[string]
			$ComputerName
		)
		
		# Retrieve the Exchange Server to process
		$Forestname = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Name
		
		$configNC = ([ADSI]"LDAP://$Forestname/RootDse").configurationNamingContext
		$search = new-object DirectoryServices.DirectorySearcher([ADSI]"LDAP://$Forestname/$configNC")
		$search.Filter = "(&(objectClass=msExchExchangeServer)(networkaddress=ncacn_ip_tcp:$ComputerName))"
		$search.PageSize = 1000
		$search.PropertiesToLoad.Clear()
		$search.PropertiesToLoad.Add("serialnumber") | Out-Null
		$search.PropertiesToLoad.Add("msexchinstallpath") | Out-Null
		
		# Try to parse the string value of serial number
		$Server = $search.FindOne()
		$line = $Server.Properties["serialnumber"][0]
		
		if ($line -like "Version 14*") { return 2010 }
		elseif ($line -like "Version 15*") { return 2013 }
		elseif ($line -like "Version 16*") { return 2016 }
		
		# If this fails, try to get the version number from setup.exe
		try
		{
			$installpath = $Server.Properties["msexchinstallpath"][0]
			$path = "\\$ComputerName\$($installpath.Replace(":", '$'))\bin\setup.exe"
			$Version = ([Version]([System.Diagnostics.FileVersionInfo]::GetVersionInfo($path).ProductVersion)).Major
			
			switch ($Version)
			{
				14 { return 2010 }
				15 { return 2013 }
				16 { return 2016 }
				default { throw "Unknown Exchange Version!" }
			}
		}
		catch
		{
			throw "Failed to detect Exchange Version number! Both AD and file query failed for $ComputerName!"
		}
	}
	
	function Test-ExchangeCentralAdmin
	{
		[CmdletBinding()]
		Param (
			[string]
			$ComputerName,
			
			[string]
			$VersionString
		)
		
		try
		{
			# If the key for central admin exists, return true, otherwise it will error (accessing nonexisting key) and return $false in the catch
			$RootKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $ComputerName)
			$TargetKey = $null
			$TargetKey = $RootKey.OpenSubKey("Software\Microsoft\ExchangeServer\v$VersionString\CentralAdmin")
			if ($TargetKey -eq $null) { return $false }
			return $true
		}
		catch
		{
			return $false
		}
	}
	#endregion Utility Functions
	
	#region Detect Exchange to use ($HostName)
	if (-not ($PSBoundParameters.ContainsKey('ComputerName')))
	{
		try { $ComputerName = Get-ClosestExchangeServer -ErrorAction Stop }
		catch
		{
			if ($Silent) { throw (New-Object System.OperationCanceledException("Exchange Autodiscovery failed! $($_.Exception.Message)", $_.Exception)) }
			else
			{
				Write-Warning "Failed to detect an Exchange Server! $($_.Exception.Message)"
				return
			}
		}
	}
	
	try
	{
		$HostName = [System.Net.Dns]::GetHostEntry($ComputerName).HostName
	}
	catch
	{
		if ($Silent) { throw (New-Object System.OperationCanceledException("Exchange name could not be resolved! $($_.Exception.Message)", $_.Exception)) }
		else
		{
			Write-Warning "Exchange name could not be resolved! $($_.Exception.Message)"
			return
		}
	}
	#endregion Detect Exchange to use ($HostName)
	
	if ($Light)
	{
		if ($Credential) { Connect-ExchangeServer -ComputerName $HostName -Light -Authentication $Authentication -Credential $Credential -SessionTimeout $SessionTimeout -ModulePath $ModulePath }
		else { Connect-ExchangeServer -ComputerName $HostName -Light -Authentication $Authentication -SessionTimeout $SessionTimeout -ModulePath $ModulePath }
		
		return
	}
	
	#region Detect Exchange Version ($Version, $VNString)
	try { $Version = Get-ExchangeVersion -ComputerName $HostName -ErrorAction Stop }
	catch
	{
		if ($Silent) { throw (New-Object System.OperationCanceledException("Exchange version detection failed! $($_.Exception.Message)", $_.Exception)) }
		else
		{
			Write-Warning "Exchange version detection failed! $($_.Exception.Message)"
			return
		}
	}
	
	switch ($Version)
	{
		2010 { $VNString = "14" }
		2013 { $VNString = "15" }
		2016 { $VNString = "16" }
	}
	#endregion Detect Exchange Version ($Version, $VNString)
	
	#region Ensure local files are present
	
	#region Test, whether the Exchange Shell was installed locally.
	
	# By default we assume to not have a local isntallation of ExchangeShell
	$IsLocal = $false
	
	try
	{
		$InstallPath = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\ExchangeServer\v$VNString\Setup" -Name MsiInstallPath -ErrorAction Stop | Select-Object -ExpandProperty MsiInstallPath
		$ProductMajor = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\ExchangeServer\v$VNString\Setup" -Name MsiProductMajor -ErrorAction Stop | Select-Object -ExpandProperty MsiProductMajor
		
		$IsLocal = (($InstallPath -gt "") -and ($ProductMajor -eq $VNString))
	}
	catch { }
	
	if ($IsLocal)
	{
		# Set critical globals
		$global:exinstall = $InstallPath
		$global:exbin = $InstallPath + "bin\"
		$global:exscripts = $InstallPath + "scripts\"
		
		# Write warning, as cleaning local files is not supported with an Exchange Shell already installed
		if ($Force)
		{
			Write-Warning @"
Local ExchangeShell Installation for Exchange Version $Version was detected in registry, Force parameter will be ignored!
The ExchangeShell libraries will be used for the connection. If this fails due to version mismatch, there are two options:
- Manually uninstall the ExchangeShell
- Use this command in light mode ("-Light" parameter), which does not use libraries at all and relies on PowerShell remoting.

The Registry-keys used to detect installations was:
HKLM:\SOFTWARE\Microsoft\ExchangeServer\v$VNString\Setup : MsiInstallPath
HKLM:\SOFTWARE\Microsoft\ExchangeServer\v$VNString\Setup : MsiProductMajor
"@
		}
	}
	
	#endregion Test, whether the Exchange Shell was installed locally.
	
	#region Transfer Files and register paths if not installed locally
	
	if (-not $IsLocal)
	{
		#region preliminaries
		# Declare target path
		$ExPath = $env:ProgramFiles + "\Microsoft\Exchange Server\V$VNString\"
		
		# If Force was set, clean up local files before importing
		if ($Force -and (Test-Path $ExPath))
		{
			Get-ChildItem $ExPath -Force | Remove-Item -Force -Confirm:$false -Recurse
		}
		
		# Test whether the module files were already loaded
		$AlreadyLoaded = $false
		if (Test-Path $ExPath) { $AlreadyLoaded = (Get-ChildItem $ExPath -Force -Recurse | Measure-Object | Select-Object -ExpandProperty Count) -gt 4000 }
		#endregion preliminaries
		
		#region Is not yet loaded
		if (!$AlreadyLoaded)
		{
			Write-Warning "Copying library and resource files. This may take a while"
			
			#region Connect to Exchange and read remote paths
			Try
			{
				$global:exinstall = Get-ExchangeInstallPath -ComputerName $HostName -ErrorAction Stop -SmbPath
			}
			Catch
			{
				if ($Silent) { throw (New-Object System.OperationCanceledException("Failed to connect to Exchange: $($_.Exception.Message)", $_.Exception)) }
				else
				{
					Write-Warning "Failed to connect to Exchange: $($_.Exception.Message)"
					return
				}
			}
			$global:exbin = Join-Path $global:exinstall "bin"
			$global:exscripts = Join-Path $global:exinstall "scripts"
			#endregion Connect to Exchange and read remote paths
			
			#region Ensure Local Path Configuration
			
			# Ensure Root folder
			if (-not (Test-Path $ExPath)) { New-Item $ExPath -ItemType 'container' -Force -Confirm:$false | Out-Null }
			
			# Ensure Registry key Existence
			if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\ExchangeServer\v$VNString\Setup")) { New-Item "HKLM:\SOFTWARE\Microsoft\ExchangeServer\v$VNString\Setup" -Force | Out-Null }
			
			# Ensure Property Value
			$item = Get-Item "HKLM:\SOFTWARE\Microsoft\ExchangeServer\v$VNString\Setup"
			Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ExchangeServer\v$VNString\Setup" -Name "MsiInstallPath" -Value $ExPath -ErrorAction 'Stop'
			
			# Ensure binaries Folder
			$tempExBin = New-Item -Path $ExPath -Name "bin" -ItemType 'Container' -Force -Confirm:$false
			
			# Ensure Public Folder
			New-Item -Path $ExPath -Name "Public" -ItemType 'Container' -Force -Confirm:$false | Out-Null
			
			# Ensure Setup Folder
			New-Item -Path $ExPath -Name "Setup" -ItemType 'Container' -Force -Confirm:$false | Out-Null
			
			#endregion Ensure Local Path Configuration
			
			#region Copy Items
			# Copy script items
			Copy-Item -Path $global:exscripts -Destination $ExPath -Recurse -Force -Confirm:$false
			$global:exscripts = Join-Path $ExPath "scripts"
			
			# Copy Binaries
			Get-ChildItem $global:exbin -Force | Where-Object { ($_.GetType().Name -eq "FileInfo") -and ($_.Attributes -notlike "*ReparsePoint*") } | Copy-Item -Destination $tempExBin -Force -Confirm:$false
			
			# Copy language resources
			$lname = [System.Threading.Thread]::CurrentThread.CurrentUICulture.TwoLetterISOLanguageName
			$lfolder = Join-Path $global:exbin $lname
			Copy-Item -Path $lfolder -Destination $tempExBin -Recurse -Force -Confirm:$false
			
			# Copy other items
			$Monitoring = Join-Path $global:exbin "Monitoring"
			Copy-Item -Path $Monitoring -Destination $tempExBin -Recurse -Force -Confirm:$false
			
			$ExtensionAgents = Join-Path $global:exbin "CmdletExtensionAgents"
			Copy-Item -Path $ExtensionAgents -Destination $tempExBin -Recurse -Force -Confirm:$false
			
			$PublicLib = Join-Path $global:exinstall "Public"
			Get-ChildItem $PublicLib | Copy-Item -Destination $tempExBin -Recurse -Force -Confirm:$false
			
			$global:exbin = $tempExBin.FullName
			#endregion Copy Items
			
			Write-Warning "Finished copying those pesky files"
		}
		#endregion Is not yet loaded
		
		#region Is already loaded
		else
		{
			$global:exinstall = $ExPath
			$global:exbin = Join-Path $ExPath "bin" | Get-Item | Select-Object -ExpandProperty "FullName"
			$global:exscripts = Join-Path $ExPath "scripts" | Get-Item | Select-Object -ExpandProperty "FullName"
		}
		#endregion Is already loaded
	}
	
	#endregion Transfer Files and register paths if not installed locally
	
	#endregion Ensure local files are present
	
	#region Import Local Files
	
	switch ($Version)
	{
		#region Exchange 2010
		2010
		{
			# Set Configuration Value for format enumeration
			$FormatEnumerationLimit = 16
			
			# Load hashtable of localized string
			Import-LocalizedData -BindingVariable RemoteExchange_LocalizedStrings -FileName "RemoteExchange.strings.psd1" -BaseDirectory $global:exbin
			
			#region Load Exchange Types
			function GetTypeListFromXmlFile([string]$typeFileName)
			{
				$xmldata = [xml](Get-Content $typeFileName)
				$returnList = $xmldata.Types.Type | Where-Object { ($_.Name.StartsWith("Microsoft.Exchange") -and !$_.Name.Contains("[[")) } | ForEach-Object { $_.Name }
				return $returnList
			}
			
			$ConfigurationPath = Join-Path $global:exbin "Microsoft.Exchange.Configuration.ObjectModel.dll" | Get-Item | Select-Object -ExpandProperty "FullName"
			[System.Reflection.Assembly]::LoadFrom($ConfigurationPath) | Out-Null
			
			# Check if every single type from from Exchange.Types.ps1xml can be successfully loaded
			$ManagementPath = Join-Path $global:exbin "Microsoft.Exchange.Management.dll" | Get-Item | Select-Object -ExpandProperty "FullName"
			$typeFilePath = Join-Path $global:exbin "exchange.types.ps1xml" | Get-Item | Select-Object -ExpandProperty "FullName"
			$typeListToCheck = GetTypeListFromXmlFile $typeFilePath
			$typeLoadResult = [Microsoft.Exchange.Configuration.Tasks.TaskHelper]::TryLoadExchangeTypes($ManagementPath, $typeListToCheck)
			#endregion Load Exchange Types
			
			#region Import Central Admin items
			$CentralAdmin = Test-ExchangeCentralAdmin -ComputerName $HostName -VersionString $VNString
			if ($CentralAdmin)
			{
				$CentralAdminPath = Join-Path $global:exbin "Microsoft.Exchange.Management.Powershell.CentralAdmin.dll"
				[Microsoft.Exchange.Configuration.Tasks.TaskHelper]::LoadExchangeAssemblyAndReferences($CentralAdminPath) | Out-Null
			}
			#endregion Import Central Admin items
			
			#region Miscellaneous & load type information into Powershell
			# Register Assembly Resolver to handle generic types
			[Microsoft.Exchange.Data.SerializationTypeConverter]::RegisterAssemblyResolver()
			
			# Finally, load the types information
			# We will load type information only if every single type from Exchange.Types.ps1xml can be successfully loaded
			if ($typeLoadResult)
			{
				Update-TypeData -PrependPath $typeFilePath
			}
			else
			{
				# put a short warning message here that we are skipping type loading
				write-host -ForegroundColor Yellow "The Exchange types file wasn't loaded because not all of the required files could be found."
			}
			
			#load partial types
			$partialTypeFile = join-path $global:exbin "Exchange.partial.Types.ps1xml"
			Update-TypeData -PrependPath $partialTypeFile
			
			# If Central Admin cmdlets are installed, it loads the types information for those too
			if ($CentralAdmin)
			{
				$typeFile = join-path $global:exbin "Exchange.CentralAdmin.Types.ps1xml"
				Update-TypeData -PrependPath $typeFile
			}
			#endregion Miscellaneous & load type information into Powershell
		}
		#endregion Exchange 2010
		
		#region Exchange 2013
		2013
		{
			# Load hashtable of localized string
			Import-LocalizedData -BindingVariable RemoteExchange_LocalizedStrings -FileName "RemoteExchange.strings.psd1" -BaseDirectory $global:exbin
			
			# Add important types
			"Microsoft.Exchange.Data.dll", "Microsoft.Exchange.Configuration.ObjectModel.dll" | ForEach-Object {
				[System.Reflection.Assembly]::LoadFrom((Join-Path $global:exbin $_))
			} | Out-Null
			
			$FormatEnumerationLimit = 16
			
			# loads powershell types file, parses out just the type names and returns an array of string
			# it skips all template types as template parameter types individually are defined in types file
			function GetTypeListFromXmlFile([string]$typeFileName)
			{
				$xmldata = [xml](Get-Content $typeFileName)
				$returnList = $xmldata.Types.Type | Where-Object { (($_.Name.StartsWith("Microsoft.Exchange") -or $_.Name.StartsWith("Microsoft.Office.CompliancePolicy")) -and !$_.Name.Contains("[[")) } | ForEach-Object { $_.Name }
				return $returnList
			}
			
			# Check if every single type from from Exchange.Types.ps1xml can be successfully loaded
			$typeFilePath = Join-Path $global:exbin "exchange.types.ps1xml"
			$typeListToCheck = GetTypeListFromXmlFile $typeFilePath
			# Load all management cmdlet related types.
			$assemblyNames = [Microsoft.Exchange.Configuration.Tasks.CmdletAssemblyHelper]::ManagementCmdletAssemblyNames
			$typeLoadResult = [Microsoft.Exchange.Configuration.Tasks.CmdletAssemblyHelper]::EnsureTargetTypesLoaded($assemblyNames, $typeListToCheck)
			# $typeListToCheck is a big list, release it to free up some memory
			$typeListToCheck = $null
			
			$SupportPath = Join-Path $global:exbin "Microsoft.Exchange.Management.Powershell.Support.dll"
			[Microsoft.Exchange.Configuration.Tasks.TaskHelper]::LoadExchangeAssemblyAndReferences($SupportPath) | Out-Null
			
			if (Test-ExchangeCentralAdmin -ComputerName $HostName -VersionString $VNString)
			{
				$CentralAdminPath = Join-Path $global:exbin "Microsoft.Exchange.Management.Powershell.CentralAdmin.dll"
				[Microsoft.Exchange.Configuration.Tasks.TaskHelper]::LoadExchangeAssemblyAndReferences($CentralAdminPath) | Out-Null
			}
			
			# Register Assembly Resolver to handle generic types
			[Microsoft.Exchange.Data.SerializationTypeConverter]::RegisterAssemblyResolver()
			
			
			# Finally, load the types information
			# We will load type information only if every single type from Exchange.Types.ps1xml can be successfully loaded
			if ($typeLoadResult)
			{
				Update-TypeData -PrependPath $typeFilePath
			}
			else
			{
				Write-Error $RemoteExchange_LocalizedStrings.res_types_file_not_loaded
			}
			
			#load partial types
			$partialTypeFile = Join-Path $global:exbin "Exchange.partial.Types.ps1xml"
			Update-TypeData -PrependPath $partialTypeFile
			
			# If Central Admin cmdlets are installed, it loads the types information for those too
			if (Test-ExchangeCentralAdmin -ComputerName $HostName -VersionString $VNString)
			{
				$typeFile = Join-Path $global:exbin "Exchange.CentralAdmin.Types.ps1xml"
				Update-TypeData -PrependPath $typeFile
			}
			
			# Loads FFO-specific type and formatting xml files.
			$ffoTypeData = Join-Path $global:exbin "Microsoft.Forefront.Management.Powershell.types.ps1xml"
			$ffoFormatData = Join-Path $global:exbin "Microsoft.Forefront.Management.Powershell.format.ps1xml"
			
			if ((Test-Path $ffoTypeData) -and (Test-Path $ffoFormatData))
			{
				Update-TypeData -PrependPath $ffoTypeData
				Update-FormatData -PrependPath $ffoFormatData
			}
		}
		#endregion Exchange 2013
		
		#region Exchange 2016
		2016
		{
			# Load hashtable of localized string
			Import-LocalizedData -BindingVariable RemoteExchange_LocalizedStrings -FileName "RemoteExchange.strings.psd1" -BaseDirectory $global:exbin
			
			# Add important types
			"Microsoft.Exchange.Data.dll", "Microsoft.Exchange.Configuration.ObjectModel.dll" | ForEach-Object {
				[System.Reflection.Assembly]::LoadFrom((Join-Path $global:exbin $_))
			} | Out-Null
			
			$FormatEnumerationLimit = 16
			
			# loads powershell types file, parses out just the type names and returns an array of string
			# it skips all template types as template parameter types individually are defined in types file
			function GetTypeListFromXmlFile([string]$typeFileName)
			{
				$xmldata = [xml](Get-Content $typeFileName)
				$returnList = $xmldata.Types.Type | Where-Object { (($_.Name.StartsWith("Microsoft.Exchange") -or $_.Name.StartsWith("Microsoft.Office.CompliancePolicy")) -and !$_.Name.Contains("[[")) } | ForEach-Object { $_.Name }
				return $returnList
			}
			
			# Check if every single type from from Exchange.Types.ps1xml can be successfully loaded
			$typeFilePath = Join-Path $global:exbin "exchange.types.ps1xml"
			$typeListToCheck = GetTypeListFromXmlFile $typeFilePath
			# Load all management cmdlet related types.
			$assemblyNames = [Microsoft.Exchange.Configuration.Tasks.CmdletAssemblyHelper]::ManagementCmdletAssemblyNames
			$typeLoadResult = [Microsoft.Exchange.Configuration.Tasks.CmdletAssemblyHelper]::EnsureTargetTypesLoaded($assemblyNames, $typeListToCheck)
			# $typeListToCheck is a big list, release it to free up some memory
			$typeListToCheck = $null
			
			$SupportPath = Join-Path $global:exbin "Microsoft.Exchange.Management.Powershell.Support.dll"
			[Microsoft.Exchange.Configuration.Tasks.TaskHelper]::LoadExchangeAssemblyAndReferences($SupportPath) | Out-Null
			
			if (Test-ExchangeCentralAdmin -ComputerName $HostName -VersionString $VNString)
			{
				$CentralAdminPath = Join-Path $global:exbin "Microsoft.Exchange.Management.Powershell.CentralAdmin.dll"
				[Microsoft.Exchange.Configuration.Tasks.TaskHelper]::LoadExchangeAssemblyAndReferences($CentralAdminPath) | Out-Null
			}
			
			# Register Assembly Resolver to handle generic types
			[Microsoft.Exchange.Data.SerializationTypeConverter]::RegisterAssemblyResolver()
			
			
			# Finally, load the types information
			# We will load type information only if every single type from Exchange.Types.ps1xml can be successfully loaded
			if ($typeLoadResult)
			{
				Update-TypeData -PrependPath $typeFilePath
			}
			else
			{
				Write-Error $RemoteExchange_LocalizedStrings.res_types_file_not_loaded
			}
			
			#load partial types
			$partialTypeFile = Join-Path $global:exbin "Exchange.partial.Types.ps1xml"
			Update-TypeData -PrependPath $partialTypeFile
			
			# If Central Admin cmdlets are installed, it loads the types information for those too
			if (Test-ExchangeCentralAdmin -ComputerName $HostName -VersionString $VNString)
			{
				$typeFile = Join-Path $global:exbin "Exchange.CentralAdmin.Types.ps1xml"
				Update-TypeData -PrependPath $typeFile
			}
			
			# Loads FFO-specific type and formatting xml files.
			$ffoTypeData = Join-Path $global:exbin "Microsoft.Forefront.Management.Powershell.types.ps1xml"
			$ffoFormatData = Join-Path $global:exbin "Microsoft.Forefront.Management.Powershell.format.ps1xml"
			
			if ((Test-Path $ffoTypeData) -and (Test-Path $ffoFormatData))
			{
				Update-TypeData -PrependPath $ffoTypeData
				Update-FormatData -PrependPath $ffoFormatData
			}
		}
		#endregion Exchange 2016
	}
	
	#endregion Import Local Files
	
	# Finally: Connect
	if ($Credential) { Connect-ExchangeServer -ComputerName $HostName -Authentication $Authentication -Credential $Credential -SessionTimeout $SessionTimeout -ModulePath $ModulePath }
	else { Connect-ExchangeServer -ComputerName $HostName -Authentication $Authentication -SessionTimeout $SessionTimeout -ModulePath $ModulePath }
}
