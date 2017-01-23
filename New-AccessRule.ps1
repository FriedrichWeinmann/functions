function New-AccessRule
{
	<#
		.SYNOPSIS
			Creates a new FileSystem AccessRule.
	
		.DESCRIPTION
			Creates a new FileSystem AccessRule, which can be added to an Acl.
			Defaults to:
			- Modify Permissions
			- To Object and all children
	
		.PARAMETER Name
			Alias:   user, username, samaccountname, alias
			The name of the user or group that is affected by the rule.
	
		.PARAMETER Domain
			Default: $env:USERDOMAIN
			The name of the domain that user or group belongs to.
	
		.PARAMETER Permission
			Options: FullControl, ReadOnly, DontTouchMyFolders, Modify
			Default: Modify
			ParSet:  PreSet
			The permissions applied to the AccessRule. Choose one of several preconfigured Permission-Sets:
			- FullControl        Allows any action, including changing permissions.
			- ReadOnly           Allows only to read content.
			- DontTouchMyFolders Allows changing files, but not folders
			- Modify             Allows changing files and folders, but not setting permissions.
	
			For more detailed control over permission-levels, see the "Rights" parameter.
	
		.PARAMETER Rights
			ParSet:  Custom
			Alternatively to using a preconfigured permission-set, this parameter allows to freely assign any permission desired.
			For comfortable use of preconfigured common permissions, see the "Permission" parameter above.
	
		.PARAMETER Inheritance
			Options: None, Files, Folders, All
			Default: All
			Defines the kind of objects these permissions are inherited by.
	
		.PARAMETER ChildrenOnly
			Permissions only affect children of the target object, not the object itself.
	
		.PARAMETER Deny
			Creates a deny rule, instead of an allow rule.
	
		.EXAMPLE
			PS C:\> New-AccessRule "Fred"
	
			Creates an AccessRule that will allow the user Fred (who is of the same domain as the User executing the command) Modify permissions that are also inherited by all childitems on the item this rule is applied upon.
	
		.EXAMPLE
			PS C:\> Get-Content "C:\Users.txt" | New-AccessRule -Permission ReadOnly
	
			For each user in users.txt a new accessrule will be created, each of those will have ReadOnly permissions.
	
		.EXAMPLE
			PS C:\> New-AccessRule "Fred" -Permission "Modify" -ChildrenOnly
	
			This will create an AccessRule that will grant modify permissions to Fred, but only to the child items of the folders this rule will be applied to, not to the folders themselves (however, permissions will be granted for the child folders).
	
		.NOTES
			Supported Interfaces:
			------------------------
			
			Author:			Friedrich Weinmann
			Company:		die netzwerker Computernetze GmbH
			Created:		18.11.2013
			LastChanged:	26.05.2014
			Version:		2.0
	#>
	[CmdletBinding(DefaultParameterSetName = "PreSet")]
	Param (
		[Parameter(Position = 0, ValueFromPipeline = $True, Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
		[Alias('user', 'username', 'samaccountname', 'alias')]
		[String[]]
		$Name,
		
		[String]
		$Domain = $env:USERDOMAIN,
		
		[Parameter(ParameterSetName = "PreSet", Position = 1)]
		[ValidateSet("FullControl", "ReadOnly", "DontTouchMyFolders", "Modify")]
		[String]
		$Permission = "Modify",
		
		[Parameter(ParameterSetName = "Custom", Position = 1)]
		[System.Security.AccessControl.FileSystemRights]
		$Rights = [System.Security.AccessControl.FileSystemRights]::Modify,
		
		[ValidateSet("None", "Files", "Folders", "All")]
		[String]
		$Inheritance = "All",
		
		[switch]
		$ChildrenOnly,
		
		[switch]
		$Deny
	)
	
	Begin
	{
		# Store the active Parameterset
		$ParSet = $PSCmdlet.ParameterSetName
	}
	Process
	{
		foreach ($uname in $Name)
		{
			# Set Name
			$User = $Domain + "\" + $uname
			
			# Set Permission Level
			switch ($ParSet)
			{
				"PreSet"
				{
					# If one of the preconfigured sets was chosen
					switch ($Permission.ToLower())
					{
						"fullcontrol" { $FileSystemRights = [System.Security.AccessControl.FileSystemRights]::FullControl }
						"readonly" { $FileSystemRights = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute }
						"donttouchmyfolders" { $FileSystemRights = @([System.Security.AccessControl.FileSystemRights]::Write) }
						"modify" { $FileSystemRights = [System.Security.AccessControl.FileSystemRights]::Modify }
					}
				}
				"Custom"
				{
					# If custom permissions were entered.
					$FileSystemRights = $Rights
				}
			}
			
			# Configure Inheritance
			switch ($Inheritance.ToLower())
			{
				"none" { $InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::None }
				"folders" { $InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit }
				"files" { $InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::ObjectInherit }
				"all" { $InheritanceFlags = @([System.Security.AccessControl.InheritanceFlags]::ObjectInherit, [System.Security.AccessControl.InheritanceFlags]::ContainerInherit) }
			}
			
			# Configure Propagation
			if ($ChildrenOnly) { $PropagationFlags = [System.Security.AccessControl.PropagationFlags]::InheritOnly }
			else { $PropagationFlags = [System.Security.AccessControl.PropagationFlags]::None }
			
			# Switch between allow and deny
			if ($Deny) { $AccessControlType = [System.Security.AccessControl.AccessControlType]::Deny }
			else { $AccessControlType = [System.Security.AccessControl.AccessControlType]::Allow }
			
			# Erstellt die Regel
			$Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($User, $FileSystemRights, $InheritanceFlags, $PropagationFlags, $AccessControlType)
			$Rule
		}
	}
	End
	{
		
	}
}
