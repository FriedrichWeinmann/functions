function Test-ADGroupMembership
{
	<#
		.SYNOPSIS
			Tests whether a given AD Principal is member of a given group.
		
		.DESCRIPTION
			Tests whether a given AD Principal is member of a given group.
		
		.PARAMETER InputObject
			Alias: user, username, samaccountname, computer, cn, group, dn
			The object to be tested with.
		
		.PARAMETER MemberOf
			Alias: target, targetgroup, member
			The group to be checked whether the subject is a part of it.
		
		.PARAMETER Recurse
			If this switch is set, the function will search recursively, trying to find membership in member-groups of the target group.
	
		.PARAMETER Quiet
			If this switch is set, the function will only return $true if all InputObjects are part of the group or $false if any one is not.
	
		.PARAMETER  NoRes
			Internal Use Only.
		
		.EXAMPLE
			PS C:\> Test-ADGroupMembership -user "FWN" -MemberOf "Domain-Admins" -Recurse
			
			This will check whether FWN is part of either the Domain-Admins Group directly, or one of its member groups.
		
		.NOTES
			Supported Interfaces:
			------------------------
			Result Caching Interface
			Stores full Result
			------------------------
			
			Author:       Friedrich Weinmann
			Company:      die netzwerker Computernetze GmbH
			Created:      23.06.2014
			LastChanged:  23.06.2014
			Version:      1.0
	#>
	
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0)]
		[Alias('user', 'username', 'samaccountname', 'computer', 'cn', 'group', 'dn')]
		[Object]
		$InputObject,
		
		[Parameter(Mandatory = $true,
				   Position = 1)]
		[Alias('target', 'targetgroup', 'member')]
		[Object]
		$MemberOf,
		
		[Switch]
		$Recurse,
		
		[Switch]
		$Quiet,
		
		[Switch]
		$NoRes
	)
	
	Begin
	{
		# Load Active Directory Cmdlets
		if ((Get-Module ActiveDirectory) -eq $null)
		{
			Try { Import-ActiveDirectory -Silent }
			Catch { Throw (New-Object System.InvalidOperationException("Active Directory Module not available, interrupting Execution", $_)) }
		}
		
		# Ensure valid MemberOf target
		if ($MemberOf.GetType().FullName -eq "Microsoft.ActiveDirectory.Management.ADGroup") { }
		else
		{
			try { $MemberOf = Get-ADGroup $MemberOf -ErrorAction 'Stop' }
			catch { throw (New-Object System.ArgumentException("Can't resolve MemberOf Target", $_)) }
		}
		
		# Gather results
		$Results = @()
		$FalseEntry = @()
		
		#region recursive Search function
		function Test-Membership
		{
			Param (
				$Object,
				$Group,
				[bool]
				$Recurse
			)
			
			# Scan group
			$Members = @(Get-ADGroupMember $Group)
			if ($Members.Length -gt 0)
			{
				$IsDirect = ($Members | Select -ExpandProperty DistinguishedName) -contains $Object.DistinguishedName
				if ($IsDirect) { return (New-Object PSObject -Property @{ Object = $Object; IsMember = $true }) }
			}
			else { return (New-Object PSObject -Property @{ Object = $Object; IsMember = $false }) }
			
			if ($Recurse)
			{
				$Groups = @($Members | Where { $_.ObjectClass -eq "group" })
				if ($Groups.Length -eq 0) { return (New-Object PSObject -Property @{ Object = $Object; IsMember = $false }) }
				else
				{
					$res = @()
					$groups | %{ $res += Test-Membership -Object $Object -Group $_ -Recurse $true }
					return (New-Object PSObject -Property @{ Object = $Object; IsMember = (($res | Select -ExpandProperty IsMember) -contains $true) })
				}
			}
			
			return (New-Object PSObject -Property @{ Object = $Object; IsMember = $false })
		}
		#endregion
	}
	Process
	{
		# Iterate over each input object
		foreach ($object in $InputObject)
		{
			# Test Variable that controls whether a search is conducted (will be set to false if invalid input)
			$test = $true
			
			# Get the input type for swift switching
			$Type = $object.GetType().FullName
			switch ($Type)
			{
				"Microsoft.ActiveDirectory.Management.ADUser" { }
				"Microsoft.ActiveDirectory.Management.ADComputer" { }
				"Microsoft.ActiveDirectory.Management.ADGroup" { }
				default
				{
					$obj = $null
					
					# Try to turn the input into an AD Object
					Try { $obj = Get-ADUser $object -ErrorAction 'Stop' }
					Catch { }
					if ($obj -eq $null)
					{
						Try { $obj = Get-ADComputer $object -ErrorAction 'Stop' }
						Catch { }
					}
					if ($obj -eq $null)
					{
						Try { $obj = Get-ADGroup $object -ErrorAction 'Stop' }
						Catch { }
					}
					if ($obj -eq $null) { $test = $false }
					else { $object = $obj }
				}
			}
			# If valid object, get searching
			if ($test)
			{
				$Results += Test-Membership -Object @($object)[0] -Group $MemberOf -Recurse:$Recurse
			}
			# Else, add to output
			else
			{
				$FalseEntry += $object
			}
		}
	}
	End
	{
		# Write Error Log if Appropriate
		if (!$Quiet -and ($FalseEntry.Length -gt 0))
		{
			Write-Warning "Invalid Input(s):"
			$FalseEntry | Out-Host
		}
		
		# Return Results
		
		# If no valid object was passed, return false
		if ($Results.Length -eq 0) { return $false }
		
		# Unless Result caching was disabled, cache results
		if (!$NoRes) { $script:NW_Result = $Results }
		
		# If not set to Quiet, return results
		if (!$Quiet) { return $Results }
		
		# If Invalid Objects exist while set to quiet, return false
		if ($Quiet -and ($FalseEntry.Length -gt 0)) { return $false }
		
		# If set to quiet, return whether all was successful
		else { return (-not (($Results | Select -ExpandProperty IsMember) -contains $false)) }
	}
}

function Import-ActiveDirectory
{
	<#
		.SYNOPSIS
			Imports the ActiveDirectory Commandlets if available.
		
		.DESCRIPTION
			Imports the ActiveDirectory Commandlets if available. Displays advice if impossible.
	
		.PARAMETER  Silent
			If this switch is set, the command will not write any output to the host, but throw errors instead, if somethign fails.
		
		.EXAMPLE
			PS C:\> Import-ActiveDirectory
	
			Tries to import the Active Directory Module.
		
		.NOTES
			Supported Interfaces:
			------------------------
			
			Author:       Friedrich Weinmann
			Company:      die netzwerker Computernetze GmbH
			Created:      11.11.2013
			LastChanged:  23.06.2014
			Version:      1.1
	#>
	
	[CmdletBinding()]
	Param (
		[switch]
		$Silent
	)
	$list = @(Get-Module -ListAvailable | Where { $_.Name -eq "ActiveDirectory" })
	if ($list.count -gt 0) { Import-Module ActiveDirectory }
	else
	{
		$objDomain = New-Object System.DirectoryServices.DirectoryEntry
		$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
		$objSearcher.SearchRoot = $objDomain
		$objSearcher.PageSize = 1000
		$objSearcher.Filter = "(&(objectCategory=computer)(primaryGroupID=516))"
		$objSearcher.SearchScope = "Subtree"
		$objSearcher.PropertiesToLoad.Add("dnshostname")
		$objSearcher.PropertiesToLoad.Add("operatingsystem")
		$dcsloaded = $objSearcher.FindAll() | Select -ExpandProperty Properties
		
		$dc2008 = @($dcsloaded | Where { $_["operatingsystem"][0] -like "Windows Server® 2008*" })
		$dc2008R2 = @($dcsloaded | Where { $_["operatingsystem"][0] -like "Windows Server 2008*" })
		$dc2012 = @($dcsloaded | Where { $_["operatingsystem"][0] -like "Windows Server 2012*" })
		if ($dc2012.Length -gt 0) { $name = $dc2012[0]["dnshostname"][0] }
		elseif ($dc2008R2.Length -gt 0) { $name = $dc2008R2[0]["dnshostname"][0] }
		elseif ($dc2008.Length -gt 0) { $name = $dc2008[0]["dnshostname"][0] }
		if ($name -ne $null)
		{
			Try
			{
				$session = New-PSSession -ComputerName $name -ErrorAction 'Stop'
				Invoke-Command -Session $session -scriptblock { import-module ActiveDirectory } -ErrorAction 'Stop'
				Import-PSSession -Session $session -Module ActiveDirectory -ErrorAction 'Stop'
			}
			Catch
			{
				$string = @"
Valid Domain controller found, but failed to load commands.
This is usually due to disabled remoting, for more information on remoting, enter:
Get-Help about_powershell_remoting
DC where remoting failed:
"@
				if (!$Silent)
				{
					Write-Host $string -ForegroundColor 'DarkRed'
					Write-Host $name -ForegroundColor 'DarkRed'
				}
				else
				{
					throw (New-Object System.InvalidOperationException("Failed to load Active Directory Module from DC", $_))
				}
			}
		}
		else
		{
			$string = @"
No ActiveDirectory Module registered, no DC available that would allow importing commands.
Install Remote Administration Tools or activate AD Administrative functions.
If neither is possible, use LDAP commandlets (Get-Command *LDAP*)
"@
			if (!$Silent) { Write-Host $string -ForegroundColor 'DarkRed' }
			else { throw (New-Object System.InvalidOperationException("Failed to load Active Directory Module, no compatible DC available")) }
		}
	}
}
