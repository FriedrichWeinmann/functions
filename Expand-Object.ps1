function Expand-Object
{
	<#
		.SYNOPSIS
			A comfortable replacement for Select-Object -ExpandProperty.
		
		.DESCRIPTION
			A comfortable replacement for Select-Object -ExpandProperty.
			Allows extracting properties with less typing and more flexibility:
	
			Preferred Properties:
			By defining a list of property-names in $DefaultExpandedProperties the user can determine his own list of preferred properties to expand. This allows using this command without specifying a property at all. It will then check the first object for the property to use (starting from the first element of the list until it finds an exact case-insensitive match).
	
			Defined Property:
			The user can specify the exact property to extract. This is the same behavior as Select-Object -ExpandProperty, with less typing (dir | exp length).
	
			Like / Match comparison:
			Specifying either like or match allows extracting any number of matching properties from each object.
			Note that this is a somewhat more CPU-expensive operation (which shouldn't matter unless with gargantuan numbers of objects).
		
		.PARAMETER Name
			ParSet: Equals, Like, Match
			The name of the Property to expand.
		
		.PARAMETER Like
			ParSet: Like
			Expands all properties that match the -Name parameter using -like comparison.
		
		.PARAMETER Match
			ParSet: Match
			Expands all properties that match the -Name parameter using -match comparison.
		
		.PARAMETER InputObject
			The objects whose properties are to be expanded.
	
		.PARAMETER RestoreDefaults
			Restores $DefaultExpandedProperties to the default list of property-names.
		
		.EXAMPLE
			PS C:\> dir | exp
	
			Expands the property whose name is the first on the defaults list ($DefaultExpandedProperties).
			By default, FullName would be expanded.
	
		.EXAMPLE
			PS C:\> dir | exp length
	
			Expands the length property of all objects returned by dir. Simply ignores those that do not have the property (folders).
	
		.EXAMPLE
			PS C:\> dir | exp name -match
	
			Expands all properties from all objects returned by dir that match the string "name" ("PSChildName", "FullName", "Name", "BaseName" for directories)
		
		.NOTES
			
			Supported Interfaces:
			------------------------
			
			Author:       Friedrich Weinmann
			Company:      die netzwerker Computernetze GmbH
			Created:      21.03.2015
			LastChanged:  21.03.2015
			Version:      1.0
	#>
	[CmdletBinding(DefaultParameterSetName = "Equals")]
	Param (
		[Parameter(Position = 0, ParameterSetName = "Equals")]
		[Parameter(Position = 0, ParameterSetName = "Like", Mandatory = $true)]
		[Parameter(Position = 0, ParameterSetName = "Match", Mandatory = $true)]
		[string]
		$Name,
		
		[Parameter(ParameterSetName = "Like", Mandatory = $true)]
		[switch]
		$Like,
		
		[Parameter(ParameterSetName = "Match", Mandatory = $true)]
		[switch]
		$Match,
		
		[Parameter(ValueFromPipeline = $true)]
		[object]
		$InputObject,
		
		[switch]
		$RestoreDefaults
	)
	
	Begin
	{
		Write-Debug "[Start] Expanding Objects"
		
		$ParSet = $PSCmdlet.ParameterSetName
		Write-Debug "Active ParameterSet: $ParSet"
		
		# Null the local scoped variable (So later checks for existence don't return super-scoped variables)
		$n9ZPiBh8CI = $null
		
		# Restore to default if necessary
		if ($RestoreDefaults) { $global:DefaultExpandedProperties = @("Definition", "Guid", "DisinguishedName", "FullName", "Name", "Length") }
	}
	
	Process
	{
		foreach ($Object in $InputObject)
		{
			switch ($ParSet)
			{
				#region Equals
				"Equals"
				{
					# If we already have determined the property to use, return it
					if ($n9ZPiBh8CI)
					{
						try
						{
							$Object.$n9ZPiBh8CI.ToString() | Out-Null
							$Object.$n9ZPiBh8CI
						}
						catch { }
						continue
					}
					
					# If a property was specified, set it and return it
					if ($PSBoundParameters["Name"])
					{
						$n9ZPiBh8CI = $Name
						try
						{
							$Object.$n9ZPiBh8CI.ToString() | Out-Null
							$Object.$n9ZPiBh8CI
						}
						catch { }
						continue
					}
					
					# Otherwise, search through defaults and try to match
					foreach ($Def in $DefaultExpandedProperties)
					{
						if (Get-Member -InputObject $Object -MemberType 'Properties' -Name $Def)
						{
							$n9ZPiBh8CI = $Def
							try
							{
								$Object.$n9ZPiBh8CI.ToString() | Out-Null
								$Object.$n9ZPiBh8CI
							}
							catch { }
							break
						}
					}
				}
				#endregion Equals
				
				#region Like
				"Like"
				{
					# Return all properties whose name are similar
					foreach ($prop in (Get-Member -InputObject $Object -MemberType 'Properties' | Where-Object { $_.Name -like $Name } | Select-Object -ExpandProperty Name))
					{
						try
						{
							$Object.$prop.ToString() | Out-Null
							$Object.$prop
						}
						catch { }
					}
					continue
				}
				#endregion Like
				
				#region Match
				"Match"
				{
					# Return all properties whose name match
					foreach ($prop in (Get-Member -InputObject $Object -MemberType 'Properties' | Where-Object { $_.Name -match $Name } | Select-Object -ExpandProperty Name))
					{
						try
						{
							$Object.$prop.ToString() | Out-Null
							$Object.$prop
						}
						catch { }
					}
					continue
				}
				#endregion Match
			}
		}
	}
	
	End
	{
		Write-Debug "[End] Expanding Objects"
	}
}
New-Alias -Name "expand" -Value "Expand-Object" -Option 'AllScope'
New-Alias -Name "exp" -Value "Expand-Object" -Option 'AllScope'
$global:DefaultExpandedProperties = @("Definition", "Guid", "DisinguishedName", "FullName", "Name", "Length")
