function Test-CommandHelp
{
	<#
		.SYNOPSIS
			Tests the help of a command.
		
		.DESCRIPTION
			This function performs a pester test on the help of a given function.
			It will test, whether all pieces of help best practices require are available.
		
		.PARAMETER Command
			ParSet:  Info
			The command that will be verified.
		
		.PARAMETER CommandName
			ParSet:  Name
			The command that will be verified.
		
		.PARAMETER ModuleName
			Default: $script:ModuleName
			ParSet:  Name
			The module, from which the command comes.
		
		.PARAMETER ModuleVersion
			Default: $script:ModuleVersion
			ParSet:  Name
			The version of the module to retrieve the help from.
		
		.EXAMPLE
			PS C:\> Test-CommandHelp -Command (Get-Command Get-Help)
	
			This will test, whether Get-Help has the necessary help documentation available.
	
		.EXAMPLE
			PS C:\> Test-CommandHelp -CommandName "Get-PFSResultCache"
	
			This will test, whether the command "Get-PFSResultCache" has the necessary help documentation available.
			It assumes the function to be in the current module, with the module declaring both the $ModuleName and $ModuleVersion variables.
		
		.NOTES
			Author:     Friedrich Weinmann
			Company:    Infernal Associates ltd.
			Created On: 23.12.2016
			Changed On: 23.12.2016
			Version:    1.0
	
			Special thanks to June Blender, this function is based on her work:
			https://github.com/juneb/PesterTDD/blob/master/InModule.Help.Tests.ps1
			
			Version History
			1.0 (23.12.2016)
			- Initial release
	#>
	[CmdletBinding(DefaultParameterSetName = "Name")]
	Param (
		[Parameter(Mandatory = $true, ParameterSetName = "Info")]
		[System.Management.Automation.CommandInfo]
		$Command,
		
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Name")]
		[string]
		$CommandName,
		
		[Parameter(Mandatory = $false, Position = 1, ParameterSetName = "Name")]
		[string]
		$ModuleName = $script:ModuleName,
		
		[Parameter(Mandatory = $false, Position = 2, ParameterSetName = "Name")]
		[version]
		$ModuleVersion = $script:ModuleVersion
	)
	
	#region Utility Functions
	function Get-ParametersDefaultFirst
	{
		<#
			.SYNOPSIS
				Gets command parameters; one per name. Prefers default parameter set.
		
			.DESCRIPTION
				Gets one CommandParameterInfo object for each parameter in the specified
				command. If a command has more than one parameter with the same name, this
				function gets the parameters in the default parameter set, if one is specified.
				For example, if a command has two parameter sets:
					Name, ID  (default)
					Name, Path
				This function returns:
			    	Name (default), ID Path
				This function is used to get parameters for help and for help testing.
		
			.PARAMETER Command
				Enter a CommandInfo object, such as the object that Get-Command returns. You
				can also pipe a CommandInfo object to the function.
				This parameter takes a CommandInfo object, instead of a command name, so
				you can use the parameters of Get-Command to specify the module and version 
				of the command.
		
			.EXAMPLE
				PS C:\> Get-ParametersDefaultFirst -Command (Get-Command New-Guid)
			
				This command uses the Command parameter to specify the command to 
				Get-ParametersDefaultFirst
		
			.EXAMPLE
				PS C:\> Get-Command New-Guid | Get-ParametersDefaultFirst
		
				You can also pipe a CommandInfo object to Get-ParametersDefaultFirst
		
			.EXAMPLE
				PS C:\> Get-ParametersDefaultFirst -Command (Get-Command BetterCredentials\Get-Credential)
		
				You can use the Command parameter to specify the CommandInfo object. This
				command runs Get-Command module-qualified name value.
		
			.EXAMPLE
				PS C:\> $ModuleSpec = @{ModuleName='BetterCredentials';RequiredVersion=4.3}
				PS C:\> Get-Command -FullyQualifiedName $ModuleSpec | Get-ParametersDefaultFirst
		
				This command uses a Microsoft.PowerShell.Commands.ModuleSpecification object to 
				specify the module and version. You can also use it to specify the module GUID.
				Then, it pipes the CommandInfo object to Get-ParametersDefaultFirst.
		
			.NOTES
				Author: June Blender
				Created On: 4/12/2016
		#>
		[CmdletBinding()]
		Param
		(
			[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
			[System.Management.Automation.CommandInfo]
			$Command
		)
		
		Begin
		{
			$Common = 'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction', 'InformationVariable', 'OutBuffer', 'OutVariable', 'PipelineVariable', 'Verbose', 'WarningAction', 'WarningVariable'
			$parameters = @()
		}
		Process
		{
			if ($defaultPSetName = $Command.DefaultParameterSet)
			{
				$defaultParameters = $Command.ParameterSets | Where-Object { $_.Name -eq $defaultPSetName } | Select-Object -ExpandProperty parameters | Where-Object { $_.Name -NotIn $common }
				$otherParameters = $Command.ParameterSets | Where-Object { $_.Name -ne $defaultPSetName } | Select-Object -ExpandProperty parameters | Where-Object { $_.Name -NotIn $common }
				
				$parameters += $defaultParameters
				if ($parameters -and $otherParameters)
				{
					$otherParameters | ForEach-Object {
						if ($_.Name -notin $parameters.Name)
						{
							$parameters += $_
						}
					}
					$parameters = $parameters | Sort-Object Name
				}
			}
			else
			{
				$parameters = $Command.ParameterSets.Parameters | Where-Object { $_.Name -NotIn $common } | Sort-Object Name -Unique
			}
			
			
			return $parameters
		}
		End { }
	}
	#endregion Utility Functions
	
	# Validation variable
	$failed = $false
	
	#region Preevaluate input and retrieve help
	if ($PSCmdlet.ParameterSetName -eq "Name")
	{
		$ms = [Microsoft.PowerShell.Commands.ModuleSpecification]@{ ModuleName = $ModuleName; RequiredVersion = $ModuleVersion }
		try { $Command = Get-Command -Name $CommandName -FullyQualifiedModule $ms -ErrorAction Stop }
		catch { $failed = $true }
	}
	
	if ($Command.GetType().FullName -eq "System.Management.Automation.AliasInfo")
	{
		$Command = $Command.ResolvedCommand
	}
	
	try { $Help = Get-Help "$($Command.ModuleName)\$($Command.Name)" -ErrorAction Stop}
	catch { $failed = $true }
	#endregion Preevaluate input and retrieve help
	
	Describe "Test help for $($Command.Name) in $($Command.ModuleName) ($($Command.Module.Version))" {
		if ($failed)
		{
			It "Command or help not found" {
				1 | Should BeEqual 2
			}
		}
		else
		{
			# If help is not found, synopsis in auto-generated help is the syntax diagram
			It "should not be auto-generated" {
				$Help.Synopsis | Should Not BeLike '*`[`<CommonParameters`>`]*'
			}
			
			# Should be a synopsis for every function
			It "gets synopsis for $commandName" {
				$Help.Synopsis | Should Not beNullOrEmpty
			}
			
			# Should be a description for every function
			It "gets description for $commandName" {
				$Help.Description | Should Not BeNullOrEmpty
			}
			
			# Should be at least one example
			It "gets example code from $commandName" {
				($Help.Examples.Example | Select-Object -First 1).Code | Should Not BeNullOrEmpty
			}
			
			# Should be at least one example description
			It "gets example help from $commandName" {
				($Help.Examples.Example.Remarks | Select-Object -First 1).Text | Should Not BeNullOrEmpty
			}
			
			Context "Test parameter help from $($Command.Name)" {
				# Get parameters. When >1 parameter with same name, 
				# get parameter from the default parameter set, if any.
				$parameters = Get-ParametersDefaultFirst -Command $command
				
				$parameterNames = $parameters.Name
				$HelpParameterNames = $Help.Parameters.Parameter.Name | Sort-Object -Unique
				
				foreach ($parameter in $parameters)
				{
					$parameterName = $parameter.Name
					$parameterHelp = $Help.parameters.parameter | Where-Object { $_.Name -EQ $parameterName }
					
					# Should be a description for every parameter
					It "gets help for parameter: $parameterName : in $commandName" {
						($parameterHelp.Description.Text -join "`n") | Should Not BeNullOrEmpty
					}
					
					# Required value in Help should match IsMandatory property of parameter
					It "help for $parameterName parameter in $commandName has correct Mandatory value" {
						$codeMandatory = $parameter.IsMandatory.toString()
						$parameterHelp.Required | Should Be $codeMandatory
					}
					
					# Parameter type in Help should match code
					It "help for $commandName has correct parameter type for $parameterName" {
						$codeType = $parameter.ParameterType.Name
						# To avoid calling Trim method on a null object.
						$helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
						$helpType | Should be $codeType
					}
				}
				
				foreach ($helpParm in $HelpParameterNames)
				{
					# Shouldn't find extra parameters in help.
					It "finds help parameter in code: $helpParm" {
						$helpParm -in $parameterNames | Should Be $true
					}
				}
			}
		}
	}
}