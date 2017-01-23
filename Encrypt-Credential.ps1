function Encrypt-Credential
{
	<#
		.SYNOPSIS
			Encrypts and writes to file a set of credentials using Windows Security of any chosen account.
		
		.DESCRIPTION
			This function stores a set of encrypted credentials in a file, for any task running under a specified user to use.
			This is accomplished by ...
	
			- Writing a temporary script file that does the encryption from clear text to encrypted
			- Setup a task under the target account (Whether System, Local account or domain account) that runs the script
			- Writes an XML file containing the Clear Text Credentials (plus some runtime information)
			- Triggers the task that runs the script.
	
			The script will then ...
			- Read the exported XML File (with the clear text credentials)
			- Remove the XML File
			- Convert the Credentials Data into Encrypted Data (using Windows Security)
			- Export the Encrypted Credentials to file
			- Remove the script file
			- Remove the Task
	
			This allows using the full benefits of Windows Security for scheduled tasks running under another user. This level of Security grants the following benefits:
			- Credentials can only be decrypted by processes running under the user that encrypted it.
			- Decryption can be performed without any special knowledge / password so long as access to the user account can be ensured.
			- Decryption can be performed after Password Change of encrypting account.
			- Credentials encrypted using a windows domain account can be decrypted on any computer in that same domain, provided that the encrypting account is used.
	
			What can be encrypted?
			Any kind of password and username pair can be passed, however only the password will be encrypted. This can include SQL Server credentials, Windows Credentials, Website logins, etc.
		
		.PARAMETER Credential
			The Credential object to encrypt. This contains the Information to Encrypt. A Credential Object can be created by using the Get-Credential Cmdlet. For examples on how to us it, see the Examples section.
		
		.PARAMETER Authentication
			Default: Get-Credential
			The Credentials used to run the task with. Only this user can decrypt the encrypted credentials.
			The User will be prompted to specify credentials if none are passed. To choose the local system as user, enter "SYSTEM" as Username. In that case, the password does not matter, will be ignored and can be left blank.
		
		.PARAMETER Path
			Alias:   FullName
			The folder in which to store the credentials. This requires the following conditions:
			- The folder must exist.
			- The user must have write permissions to this folder.
			- The user for whom encryption is performed (the user that will be running the tasks) must have write permissions to this folder.
		
		.PARAMETER FileName
			Default: "Credential"
			The name the finished, encrypted credential file will be given. File Extension will be added automatically.
		
		.EXAMPLE
			PS C:\> $Cred = Get-Credential
			PS C:\> $Auth = Get-Credential
			PS C:\> Encrypt-Credential -Credential $Cred -Authentication $Auth -Path "C:\Temp" -FileName "SQL01RootCred"
	
			Step 1:
			Store the Credentials necessary to access SQL01 Root in the variable $Cred
			
			Step 2:
			Store the Credentials of the account used to run the Scheduled Task in the variable $Auth
	
			Step 3:
			Store the encrypted $Cred Credentials in the file "SQL01RootCred.xml" which is placed in the folder "C:\temp"
	
			Once that is done, these credentials can now be read from within a task running under the user specified in $Auth, like this:
	
			# 1) Read XML File
			$Data = Import-Clixml "C:\Temp\SQL01RootCred.xml"
			 
			# 2) Build a credentials object from the information
			$Cred = New-Object System.Management.Automation.PSCredential( $Data.UserName, ($Data.Password | ConvertTo-SecurePassword) )
			 
			# 3) Access the Username
			$Cred.UserName
			 
			# 4) Access the Password
			$Cred.GetNetworkCredential().Password
		
		.NOTES
			Supported Interfaces:
			------------------------
			
			Author:       Friedrich Weinmann
			Company:      die netzwerker Computernetze GmbH
			Created:      11.02.2015
			LastChanged:  11.02.2015
			Version:      1.0
	#>
	
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[System.Management.Automation.PSCredential]
		$Credential,
		
		[System.Management.Automation.PSCredential]
		$Authentication = (Get-Credential),
		
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateScript({ Test-Path $_ -PathType 'Container' })]
		[Alias('FullName')]
		[string]
		$Path,
		
		[string]
		$FileName = "Credentials"
	)
	
	# Ensure it's running elevated
	if (-not (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))
	{
		Write-Warning "This command requires elevation"
		return
	}
	
	Write-Debug "[Start] [Encrypting Credential for specified account]"
	
	#region Preparations
	
	Write-Debug "Phase 1: Preparations and generating script file"
	
	# Generate Clear Text Password Filename & Full Path
	Write-Debug "Preparing runtime values (Paths & Names)"
	$RandomSeed = "$(Get-Random -Minimum 10000000 -Maximum 99999999)"
	$RandomName = $RandomSeed + ".xml"
	$ClearPath = Join-Path $Path $RandomName
	$FileScript = Join-Path $Path ($RandomSeed + ".ps1")
	$TaskName = "Task_$RandomSeed"
	
	# Compile script as string that will write itself to file
	Write-Debug "Writing Scriptfile for task: $FileScript"
	$scripttext = "`$ClearPath = `"$ClearPath`" `n"
	$scripttext += @'
$Data = Import-Clixml $ClearPath
Remove-Item $ClearPath -Force -Confirm:$false
$Cred = New-Object System.Management.Automation.PSCredential($Data.UserName, ($Data.Password | ConvertTo-SecureString -AsPlainText -Force))
New-Object PSObject -Property @{ UserName = $Cred.GetNetworkCredential().UserName; Password = ($Cred.Password | ConvertFrom-SecureString) } | Export-Clixml -Path (Join-Path $Data.Path $Data.CredName)
& schtasks.exe /DELETE /TN $Data.TaskName /F | Out-Null
Remove-Item $Data.ScriptFile -Force -Confirm:$false
'@
	Set-Content -Value $scripttext -Path $FileScript
	#endregion Preparations
	
	#region Setup Task
	
	Write-Debug "Phase 2: Setting up Task to encode Credentials"
	
	#region Setup Principal
	
	Write-Debug "Determining Authentication Type: Local System type or User?"
	
	#region Check for system account
	$IsLocalSystem = $false
	$IsSystem = $false
	$IsService = $false
	$IsNetwork = $false
	
	switch ($Authentication.GetNetworkCredential().UserName.ToLower())
	{
		"s-1-5-18" { $IsLocalSystem = $true; $IsSystem = $true }
		"system" { $IsLocalSystem = $true; $IsSystem = $true }
		"local system" { $IsLocalSystem = $true; $IsSystem = $true }
		"lokales system" { $IsLocalSystem = $true; $IsSystem = $true }
		"localsystem" { $IsLocalSystem = $true; $IsSystem = $true }
		"lokalessystem" { $IsLocalSystem = $true; $IsSystem = $true }
		"s-1-5-19" { $IsLocalSystem = $true; $IsService = $true }
		"local" { $IsLocalSystem = $true; $IsService = $true }
		"lokal" { $IsLocalSystem = $true; $IsService = $true }
		"local service" { $IsLocalSystem = $true; $IsService = $true }
		"lokaler dienst" { $IsLocalSystem = $true; $IsService = $true }
		"localservice" { $IsLocalSystem = $true; $IsService = $true }
		"lokalerdienst" { $IsLocalSystem = $true; $IsService = $true }
		"s-1-5-20" { $IsLocalSystem = $true; $IsNetwork = $true }
		"network" { $IsLocalSystem = $true; $IsNetwork = $true }
		"netzwerk" { $IsLocalSystem = $true; $IsNetwork = $true }
		"networkservice" { $IsLocalSystem = $true; $IsNetwork = $true }
		"netzwerkdienst" { $IsLocalSystem = $true; $IsNetwork = $true }
	}
	#endregion Check for system account
	
	if ($IsLocalSystem)
	{
		Write-Debug "Authentication Type is System"
		
		$TempName = "S-1-5-18"
		if ($IsService) { $TempName = "S-1-5-19" }
		if ($IsNetwork) { $TempName = "S-1-5-20" }
		
		$Principals = @"
    <Principal id="Author">
      <UserId>$TempName</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
"@
	}
	else
	{
		Write-Debug "Authentication Type is User"
		
		$Principals = @"
    <Principal id="Author">
      <UserId>$($Authentication.UserName)</UserId>
      <LogonType>Password</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
"@
	}
	#endregion Setup Principal
	
	#region Setup XML
	Write-Debug "Compiling XML Data for task"
	
	$Xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")</Date>
    <Author>die netzwerker Computernetze GmbH</Author>
  </RegistrationInfo>
  <Triggers />
  <Principals>
$Principals
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>P3D</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy RemoteSigned -WindowStyle "Hidden" -File "$FileScript"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
	#endregion Setup XML
	
	#region Register Task
	
	Write-Debug "Registering Task to run the script that encrypts the Credentials"
	
	# Create a Task Scheduler Com Object and connect locally
	$Sched_Service = New-Object -ComObject schedule.service
	$Sched_Service.Connect()
	
	# Get Base folder
	$Sched_RootFolder = $Sched_Service.GetFolder("\")
	
	# Create Task with all settings
	# http://msdn.microsoft.com/en-us/library/aa382575(v=vs.85).aspx
	# 1. Name of Task
	# 2. Xml Definition of task
	# 3. 0x6 = Create new task or update existing
	# 4. Username used to run task ([Domain]\User)
	# 5. Password for account
	# 6. Logon Type used (1 = Run no matter logonstate using Password)
	# 7. Special Security settings (not needed)
	if (-not $IsLocalSystem) { $Sched_RootFolder.RegisterTask($TaskName, $xml, 0x6, $Authentication.UserName, $Authentication.GetNetworkCredential().Password, 1, $null) | Out-Null }
	else { $Sched_RootFolder.RegisterTask($TaskName, $xml, 0x6, $Authentication.GetNetworkCredential().UserName, $null, 1, $null) | Out-Null }
	
	#endregion Register Task
	
	#endregion Setup Task
	
	#region Write Information & Launch Task
	
	Write-Debug "Phase 3: Writing Clear Text Credentials and running Scheduled Task"
	
	# Prepare Information and write to file
	Write-Debug "Writing Credentials in Clear Text to $ClearPath"
	$Props = @{
		UserName = $Credential.UserName
		Password = $Credential.GetNetworkCredential().Password
		Path = $Path
		CredName = "$($FileName).xml"
		ScriptFile = $FileScript
		TaskName = $TaskName
	}
	New-Object PSObject -Property $Props | Export-Clixml $ClearPath
	
	# Launch task
	Write-Debug "Running Task that will encrypt credentials and remove clear data"
	& schtasks.exe /RUN /TN $TaskName /I | Out-Null
	
	#endregion Write Information & Launch Task
	
	#region Validation
	
	# Wait a few Milliseconds for the task to run
	Start-Sleep -Milliseconds 1000
	
	Write-Debug "Phase 4: Validating Execution"
	
	# Validation Variable
	$test = $true
	
	# Validate Clear Text Credentials file
	Write-Debug "Validating Clear-Text Credentials"
	if (Test-Path $ClearPath)
	{
		Write-Debug "Result: Failure! Clear-Text Credentials have not been removed."
		Write-Warning "The Task failed to remove the file with the clear text credentials as required. Please clean up manually:"
		Write-Warning $ClearPath
		$test = $false
	}
	else { Write-Debug "Result: Success! Clear-Text Credentials have been removed." }
	
	# Validate Script File has been removed
	Write-Debug "Validating Script file removal"
	if (Test-Path $FileScript)
	{
		Write-Debug "Result: Failure! Script file has not been removed."
		Write-Warning "The Task failed to remove the script file it should run to convert credentials. Please clean up manually:"
		Write-Warning $FileScript
		$test = $false
	}
	else { Write-Debug "Result: Success! Script file has been removed." }
	
	# Validate Encrypted Credential File
	Write-Debug "Validating Encrypted Credential File"
	$CredPath = Join-Path $Path "$($FileName).xml"
	if (Test-path $CredPath) { Write-Debug "Result: Success! Encrypted Credential File has been written." }
	else
	{
		Write-Debug "Result: Failure! Encrypted Credential File has not been created"
		Write-Warning "Credentials file could not be detected!"
		$test = $false
	}
	
	# Validate Scheduled Task that runs the conversion
	Write-Debug "Validating the conversion Task"
	try
	{
		$task = $Sched_RootFolder.GetTask($TaskName)
		
		Write-Debug "Result: Failure! Task still exists - $TaskName"
		Write-Warning "Conversion task has not been removed as it should: $TaskName - Please remove manually"
		
		$test = $false
	}
	catch
	{
		Write-Debug "Result: Success! Task has remvoed itself properly"
	}
	
	#endregion Validation
	
	# Write closing line
	Write-Debug "[End] [Encrypting Credential for specified account]"
	
	return $test
}
