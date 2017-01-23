function Remove-Null
{
	<#
		.SYNOPSIS
			Removes null and empty objects.
		
		.DESCRIPTION
			Filters out all objects that are either null or empty. Useful to insert into a pipeline.
			
			This includes empty strings, empty collections, null-values, psobjects without properties, hashtables without values/bname pairs and any other representation of null that I can think of.
		
		.PARAMETER InputObject
			Alias:  i, in, object
			The list of objects that are to be filtered.
		
		.PARAMETER Restricted
			Alias:  r
			Restricts the filtering function to $null objects and empty collections of all kind.
			Overridden by -NullOnly
			Overrises -IncludeProperties
		
		.PARAMETER NullOnly
			Alias:  n
			Strictly filters out only $null-valued input.
			Overrides -Restricted and -IncludeProperties
		
		.PARAMETER Property
			Alias:  p, prop
			ParSet: Property
			The properties to check. This will cause the function to ignore most other filters and only check the content of these properties. Note that - unless -AllProperties is set - this function will pass on all objects where any of the listed properties exist.
			
			Does not accept Wildcards.
			Does not perform PSObject or HashTable validation.
		
		.PARAMETER IncludeProperties
			Alias:  ip
			ParSet: Object
			Setting this switch will cause the function to check all direct properties of an object. Any non-null property will validate as true.
			Does not evaluate primitive types.
			Overriden by -NullOnly and -Restricted
		
		.PARAMETER AllProperties
			Alias:  ap, allprops
			ParSet: Property
			This switch causes the function to require all listed properties to be present and not-null, non-empty, in order to pass through an object.
			Without this switch, all objects where at least one property is non-null will be passed through.
		
		.PARAMETER IncludeType
			Alias:  it
			All types listed here will be passed through without further inspection.
			IncludeType supercedes ExcludeType.
			Accepts Wildcards.
		
		.PARAMETER ExcludeType
			Alias:  et
			All types listed here will be dropped without further inspection.
			ExcludeType is superceded by IncludeType.
			Accepts Wildcards.
	
		.EXAMPLE
			PS C:\> Get-ADUser -Filter * | Process-Users | Remove-Null | Set-ADUser -Enabled $true
	
			Step 1: Get all user objects
			Step 2: Pass these objects into a (fictional) processing function
			Step 3: Removes all $null objects
			Step 4: Enables all users that were passed through Remove-Null
	
			Had Step 3 been skipped, Set-ADUser might have received invalid input and thrown errors.
	
		.EXAMPLE
			PS C:\> dir | rmn -it "System.IO.FileInfo" -et "*"
	
			Step 1: Get all child-items in the current directory
			Step 2: Drop all items that are not System.IO.FileInfo objects
	
			Used this way, it is possible to use Remove-Null as a type filter.
	
		.EXAMPLE
			PS C:\> Get-ADUser -Filter * -Property Organization | rmn -p Organization
	
			Step 1: Get all user objects, loading their Organization property.
			Step 2: Filter out those objects whose Organization Property is considered null ($Null, Empty String, empty list)
	
			This will return the full AD Objects, but only those who had the organization Property filled.
			
			Note: This is only an example how Remove-Null works, not a good method to get all AD Users with an Organization Property.
			Best Practice is to prefer command internal filtering functions over external filters where possible.
		
		.NOTES
			Supported Interfaces:
			------------------------
			
			Author:       Friedrich Weinmann
			Company:      die netzwerker Computernetze GmbH
			Created:      23.07.2014
			LastChanged:  23.07.2014
			Version:      1.0
	#>
	
	[CmdletBinding(DefaultParameterSetName = 'Object')]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   Position = 0)]
		[AllowNull()]
		[AllowEmptyCollection()]
		[AllowEmptyString()]
		[Alias('i', 'in', 'object')]
		[Object]
		$InputObject,
		
		[Switch]
		[Alias('r')]
		$Restricted,
		
		[Switch]
		[Alias('n')]
		$NullOnly,
		
		[Parameter(ParameterSetName = 'Property')]
		[Alias('p', 'prop')]
		[String[]]
		$Property,
		
		[Parameter(ParameterSetName = 'Object')]
		[Alias('ip')]
		[Switch]
		$IncludeProperties,
		
		[Parameter(ParameterSetName = 'Property')]
		[Alias('ap', 'allprops')]
		[Switch]
		$AllProperties,
		
		[Alias('it')]
		[string[]]
		$IncludeType,
		
		[Alias('et')]
		[string[]]
		$ExcludeType
	)
	
	Begin
	{
		# Store active Parameterset Name
		$ParSet = $PSCmdlet.ParameterSetName
	}
	Process
	{
		:main foreach ($item in $InputObject)
		{
			#region Initial validation
			# Skip all null objects
			if ($item -eq $null) { continue }
			
			# Retrieve Type name for next validation steps
			$TypeName = $item.GetType().FullName
			$Interfaces = $item.GetType().ImplementedInterfaces | Select -ExpandProperty "FullName"
			$Primitive = $item.GetType().IsPrimitive
			
			# If IncludeType was defined and types match: Passthrough and Skip
			if ($PSBoundParameters["IncludeType"]) { $IncludeType | %{ if ($TypeName -like $_) { $item; continue } } }
			
			# If ExcludeType was defined and types match: Skip
			if ($PSBoundParameters["ExcludeType"]) { $ExcludeType | %{ if ($TypeName -like $_) { continue } } }
			#endregion Initial validation
			
			switch ($ParSet)
			{
				#region Object ParameterSet
				"Object"
				{
					# If it's set to NullOnly mode, just pass it on (we already know it's not null)
					if ($NullOnly) { $item; continue main }
					
					# If it's a collection of any type
					if (($Interfaces -contains "System.Collections.ICollection") -and ($Interfaces -notcontains "System.Collections.IDictionary"))
					{
						# If it's an empty collection: skip it
						if (($item | Where { $_ -ne $null } | Measure | Select -ExpandProperty Count) -eq 0) { continue main }
						
						# If it's not a non-empty collection: Pass it through
						else { $item; continue main }
					}
					
					# If it was set restricted mode, this is the moment to pass it along and move on
					if ($Restricted) { $item; continue main }
					
					# If it was not set to restricted mode, more inspection is necessary
					else
					{
						# Empty strings are ignored
						if ($item -eq "") { continue main }
						
						# PSObject without properties are null
						if ($TypeName -eq "System.Management.Automation.PSCustomObject")
						{
							if (($item | Get-Member -MemberType "*Prop*" | Measure-Object | Select -ExpandProperty Count) -eq 0) { continue main }
						}
						
						# Hashtables without Key/Value pairs are null
						if ($TypeName -eq "System.Collections.Hashtable")
						{
							if ($item.Keys.Count -eq 0) { continue main }
						}
						
						# Perform Property check
						if (($IncludeProperties) -and (!$Primitive))
						{
							# Get list of property names
							$props = $item | Get-Member -MemberType 'Properties' | Select -ExpandProperty "Name"
							
							# Perform test
							$IsNull = $true
							$props | %{ if ($item.$_ -ne $null) { $IsNull = $false } }
							
							# Escape if is null
							if ($IsNull) { continue main }
						}
						
						# Add additional checks here
						# ...
						
						# If it didn't fail any other test, pass the item along and move on
						$item
						continue main
					}
				}
				#endregion Object ParameterSet
				
				#region Property ParameterSet
				"Property"
				{
					$AllNull = $true
					
					# Iterate over Variables
					:prop foreach ($Prop in $Property)
					{
						$IsNull = $false
						
						# Check whether it has the property
						if (($item | Get-Member $Prop -MemberType 'Properties' | Measure | Select -ExpandProperty Count) -eq 0) { $IsNull = $true }
						
						# Check against null
						if ($item.$Prop -eq $null) { $IsNull = $true }
						
						# Escape if convenient
						if ($AllProperties -and $IsNull) { continue main }
						elseif ($IsNull) { continue prop }
						
						# If not only null is being validated, continue validation
						if (!$NullOnly)
						{
							# If it's a collection of any type
							if (($Interfaces -contains "System.Collections.ICollection") -and ($Interfaces -notcontains "System.Collections.IDictionary"))
							{
								# If it's an empty collection: chekc "IsNull"
								if (($item.$Prop | Where { $_ -ne $null } | Measure | Select -ExpandProperty Count) -eq 0) { $IsNull = $true }
								
								# Escape if convenient
								if ($AllProperties -and $IsNull) { continue main }
								elseif ($IsNull) { continue prop }
							}
							
							# Continue unless Restricted mode is enabled
							if (!$IsRestricted)
							{
								# Empty strings are ignored
								if ($item.$Prop -eq "") { $IsNull = $true }
								
								# Escape if convenient
								if ($AllProperties -and $IsNull) { continue main }
								elseif ($IsNull) { continue prop }
							}
						}
						
						# If a property is not null, send item along and conitnue
						if ((!$IsNull) -and (!$AllProperties)) { $item; continue main }
					}
					
					# Send item along if nothing intervened
					if ($AllProperties) { $item }
				}
				#endregion Property ParameterSet
			}
		} # [EndOfLoop: main] Looping over each input object
	}
	End
	{
		
	}
}
Set-Alias -Name rmn -Value "Remove-Null" -Option AllScope -Force
