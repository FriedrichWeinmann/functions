function Add-Accessrule
{
	<#
		.SYNOPSIS
			Adds a rule to an Acl.
	
		.DESCRIPTION
			Adds a rule to an Acl. Accepts Pipeline input (from Acls) and adds an array of AccessRules to the Acl, before returning it. This makes it possible to make it part of a Access-Rule Pipeline construct.
	
		.PARAMETER InputObject
			Alias: acl
			The Acl that is modified, accepts pipeline input
	
		.PARAMETER Rule
			Alias: accessrule
			The rules to be added to the Acl
	
		.EXAMPLE
			$rule = New-AccessRule Peter -Permission ReadOnly
			$folders = Get-ChildItem "C:\ExampleFolder" | Where {$_.Attributes -like "*Directory*"}
			foreach ($folder in $folders){Get-Acl $folder | Add-AccessRule -Rule $rule | Set-Acl $folder}
	
			This adds reading permissions for Peter to all child-folders of C:\ExampleFolder
	
		.INPUTS
			System.Security.AccessControl.FileSystemSecurity[]
			System.Security.AccessControl.AccessRule
	
		.OUTPUTS
			System.Security.AccessControl.FileSystemSecurity[]
	
		.NOTES
			Supported Interfaces:
			------------------------
			
			Author:       Friedrich Weinmann
			Company:      die netzwerker Computernetze GmbH
			Created:      18.11.2014
			LastChanged:  05.06.2014
			Version:      1.1
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Position = 0, ValueFromPipeline = $True, Mandatory = $True)]
		[System.Security.AccessControl.FileSystemSecurity[]]
		[Alias('acl')]
		$InputObject,
		
		[Parameter(Position = 1, Mandatory = $True)]
		[System.Security.AccessControl.AccessRule[]]
		[Alias('accessrule')]
		$Rule
	)
	
	Begin
	{
		Write-Debug "[Add-AccessRule][$(Get-Date -Format 'HH:mm:ss')][Start] Applying AccessRules"
		
		# Detect whether we are using pipeline input.
		$PipelineInput = (-not $PSBOUNDPARAMETERS.ContainsKey("Acl")) -and (-not $Acl)
	}
	Process
	{
		# Prepare Acl parameters
		$Acls = @()
		if ($PipelineInput) { $Acls = @($_) }
		else { $Acls = $Acl }
		
		# Iterate over all Acl and add the rules
		$results = @()
		foreach ($A in $Acls)
		{
			$Rule | %{ Write-Debug "[Add-AccessRule][$(Get-Date -Format 'HH:mm:ss')] Applying $($_.IdentityReference):$($_.FileSystemRights) to ACL:$($A.Path)"; $A.AddAccessRule($_) }
			$results += $A
		}
		
		# Return the Acls with the rule added
		return $results
	}
	End
	{
		Write-Debug "[Add-AccessRule][$(Get-Date -Format 'HH:mm:ss')][End] Applying AccessRules"
	}
}
