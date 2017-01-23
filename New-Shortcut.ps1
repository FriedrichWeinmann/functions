#region Library
$source = @"
using System;
using System.Collections;
using System.IO;
using System.Runtime.InteropServices;

namespace Netzwerker
{
    namespace FileSystem.NTFS
    {
        public static class FileSystem
        {
            #region Create Symbolic Link
            [DllImport("kernel32.dll")]
            private static extern bool CreateSymbolicLink(
            string lpSymlinkFileName, string lpTargetFileName, SymbolicLink dwFlags);

            enum SymbolicLink
            {
                File = 0,
                Directory = 1
            }

            public static bool CreateSymbolicLink(FileSystemInfo Source, string Destination)
            {
                string type = Source.GetType().FullName;
                switch (type)
                {
                    case "System.IO.DirectoryInfo":
                        return CreateSymbolicLink(Destination, Source.FullName, SymbolicLink.Directory);
                    default:
                        return CreateSymbolicLink(Destination, Source.FullName, SymbolicLink.File);
                }
            }
            #endregion
        }
    }

    namespace Utility
    {
        public class IconLocation
        {
            public string Path;
            public int Number;

            public IconLocation(string Path, int Number)
            {
                this.Path = Path;
                this.Number = Number;
            }

            public IconLocation(Hashtable Table)
            {
                if ((!Table.ContainsKey("Path")) || (!Table.ContainsKey("Number")))
                {
                    throw new ArgumentException("Invalid Hashtable, needs to contain keys \"Number\" and \" Path\"!");
                }
                this.Path = (string)Table["Path"];
                this.Number = (int)Table["Number"];
            }

            public IconLocation(System.Management.Automation.PSObject PSo)
            {
                try
                {
                    this.Path = (string)PSo.Properties["Path"].Value;
                    this.Number = (int)PSo.Properties["Number"].Value;
                }
                catch
                {
                    throw new ArgumentException("Invalid PSObject, needs to contain properties \"Number\" and \" Path\"!");
                }
            }

            public override string ToString()
            {
                string temp = "" + Path + "," + Number;
                return temp;
            }
        }

        [Flags]
        public enum LinkPreset
        {
            Shutdown = 1,
            Restart = 2,
            Logout = 4,
        }
    }
}
"@
Add-Type $source
#endregion

#region Main Function
Function New-Shortcut
{
    <#
		.SYNOPSIS
			Creates a Shortcut.
	
		.DESCRIPTION
			A powerful tool that can create a various kind of links:
	
			Common File/Folder Links
			- Supports default folder and file links.
			- Supports specifying images for the links.
			- Supports pinning to taskbar or start.
			- Supports specifying parameters for executables.
	
			Preconfigured Links
			- Some more common Common File/Folder Links.
			  For details see the "-Preset" Parameter documentation.
	
			Hardlink Files
			- Create multiple hard links to the same file on an NTFS FileSystem.
	
			Symbolic Links / Junctions
			- Create Symbolic links / NTFS Reparse points.
	
		.PARAMETER  ShortcutTarget
			Alias:   fullname, file, folder, filepath, folderpath, target
			Default: (Get-Location).Path
			ParSet:  File, Hardlink, SymLink
			The file or folder to be linked to.
	
		.PARAMETER  Preset
			Options: Shutdown, Restart, Logout
			ParSet:  Preset
			If this parameter is set, the function will create a preconfigured shortcut. Current Presets:
	
			Shutdown
			- Creates a shutdown link under programs folder.
			- Pins it to the Startmenu (or in windows 8 to the Windows Tiles)
	
			Restart
			- Creates a restart link under programs folder.
			- Pins it to the Startmenu (or in windows 8 to the Windows Tiles)
	
			Logout
			- Creates a shutdown link under programs folder.
			- Pins it to the Startmenu (or in windows 8 to the Windows Tiles)
	
		.PARAMETER  ShortcutLocation
			Alias:   path
			Default: "$env:USERPROFILE\Desktop"
			ParSet:  File, Hardlink, SymLink
			The folder the shortcut is placed in. Defaults to the user-desktop.
	
		.PARAMETER  ArgumentsToSourceExe
			Alias:   args, arguments, param
			ParSet:  File
			Arguments applied to an exe executed through this link.
			Only works if the target is an exe file
	
		.PARAMETER  ShortcutName
			Alias:   name
			Default: Same name as source.
			ParSet:  File, Hardlink, SymLink
			The name of the shortcut, if it is to be named differently from the source.
	
		.PARAMETER  Icon
			ParSet:  File
			If the link is supposed to have an icon different from the source, this parameter accepts an IconLocation object that indicates where to find the icon.
	
			Three ways to provide Input:
			- Create the final object manually:
			PS C:\> $Icon = New-Object Netzwerker.Utility.IconLocation("File Path", IndexNumber)
			here an example with actual data:
			PS C:\> $Icon = New-Object Netzwerker.Utility.IconLocation("$env:SystemRoot\System32\SHELL32.dll", 27)
	
			- Provide a Hashtable with the values "Path" and "Number"
			'-Icon @{ Path = "File Path"; Number = IndexNumber }'
			here an example with actual data:
			'-Icon @{ Path = "$env:SystemRoot\System32\SHELL32.dll"; Number = 27 }'
	
			- Provide a PSObject with the properties "Path" and "Number"
	
		.PARAMETER  Hardlink
			ParSet:  Hardlink
			If this switch is set, the file will be hardlinked to another position.
			Trying to hardlink folders will fail.
	
		.PARAMETER  SymbolicLink
			Alias:   junction
			ParSet:  SymLink
			Setting this switch will cause the function to create a symbolic link or junction instead of a regular link.
	
		.PARAMETER  PinStart
			ParSet:  File
			If this switch is set, the link will also be pinned to the start menu.
	
		.PARAMETER  PinTask
			ParSet:  File
			If this switch is set, the link will also be pinned to the taskbar.
	
		.NOTES
			Supported Interfaces:
			------------------------
			
			Author:       Friedrich Weinmann
			Company:      die netzwerker Computernetze GmbH
			Created:      20.01.2014
			LastChanged:  28.05.2014
			Version:      3.0
	#>
	[CmdletBinding(DefaultParameterSetName = "File")]
	Param (
		[Parameter(Position = 0,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true)]
		[Parameter(ParameterSetName = "File")]
		[Parameter(ParameterSetName = "Symlink")]
		[Parameter(ParameterSetName = "Hardlink")]
		[ValidateScript({ Test-Path $_ })]
		[Alias('fullname', 'file', 'folder', 'filepath', 'folderpath', 'target')]
		[string[]]
		$ShortcutTarget = ((Get-Location).Path),
		
		[Parameter(Position = 0,
				   Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   ParameterSetName = "Preset")]
		[Netzwerker.Utility.LinkPreset]
		$Preset,
		
		[Parameter(Position = 1)]
		[Parameter(ParameterSetName = "File")]
		[Parameter(ParameterSetName = "Symlink")]
		[Parameter(ParameterSetName = "Hardlink")]
		[ValidateScript({ Test-Path $_ -PathType 'container' })]
		[Alias('path')]
		[string]
		$ShortcutLocation = ($env:USERPROFILE + "\Desktop"),
		
		[Parameter(Position = 3,
				   ParameterSetName = "File")]
		[Alias('args', 'arguments', 'param')]
		[string]
		$ArgumentsToSourceExe = "",
		
		[Parameter(Position = 2)]
		[Parameter(ParameterSetName = "File")]
		[Parameter(ParameterSetName = "Symlink")]
		[Parameter(ParameterSetName = "Hardlink")]
		[Alias('name')]
		[string]
		$ShortcutName = "",
		
		[Parameter(Position = 4,
				   ParameterSetName = "File")]
		[Netzwerker.Utility.IconLocation]
		$Icon,
		
		[Parameter(ParameterSetName = "Hardlink")]
		[switch]
		$Hardlink,
		
		[Parameter(ParameterSetName = "Symlink")]
		[Alias('junction')]
		[switch]
		$SymbolicLink,
		
		[Parameter(ParameterSetName = "File")]
		[switch]
		$PinStart,
		
		[Parameter(ParameterSetName = "File")]
		[switch]
		$PinTask
	)
	
	Begin
	{
		Write-Debug "[Start] Create Shortcuts"
		
		# Get active ParameterSet
		$ParSet = $PSCmdlet.ParameterSetName
		Write-Debug "Active ParameterSet: $ParSet"
		
		# Test for Elevation where required
		if (($ParSet -eq "SymLink") -or ($ParSet -eq "Hardlink"))
		{
			if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
			{
				Write-Warning "Elevation required for creating Symbolic Links, Junctions or Hardlinks"
				Write-Debug "Terminating due to lack of elevation"
				return $false
			}
		}
		
		# Prepare executing ComObject
		$Shell = New-Object -ComObject Shell.Application
		$Desktop = $Shell.NameSpace(0X0)
		$WshShell = New-Object -comObject WScript.Shell
		
		#region Worker-Function
		function New-NW_Link
		{
			Param (
				$Target,
				$Path,
				$Name,
				$Arguments,
				[AllowNull()]
				[Netzwerker.Utility.IconLocation]
				$Icon,
				$PinStart,
				$PinTask
			)
			
			$CountStart = $error.Count
			if ($CountStart -ge 256) { $error.RemoveAt(255); $CountStart = $error.Count }
			
			#region Create linke
			# Set name of link file.
			$ShortcutFullname = "" + (Get-Item $Path).FullName + "\" + $name + ".lnk"
			
			# Create Shortcut object
			$Shortcut = $WshShell.CreateShortcut($ShortcutFullname)
			$Shortcut.TargetPath = $Target
			$Shortcut.Arguments = $Arguments.Trim()
			$Shortcut.Save()
			#endregion
			
			#region Set icon
			if ($Icon -ne $null)
			{
				$ShortcutItem = $Desktop.ParseName($ShortcutFullname).GetLink
				$ShortcutItem.SetIconLocation($Icon.Path, $Icon.Number)
				$ShortcutItem.Save()
			}
			#endregion
			
			#region Pin it
			if ($PinStart -or $PinTask)
			{
				# Read Context-Menu options
				$Verbs = $Desktop.ParseName($ShortcutFullname).Verbs()
				foreach ($verb in $Verbs)
				{
					# Check for pin to Start
					if ($PinStart -and (($verb.Name.Replace("&", "") -like "Pin to Start") -or ($verb.Name.Replace("&", "") -like "An Startmenü anheften")))
					{
						$verb.DoIt()
					}
					# Check for pin to Taskbar
					if ($PinTask -and (($verb.Name.Replace("&", "") -like "Pin to Taskbar") -or ($verb.Name.Replace("&", "") -like "An Taskleiste anheften")))
					{
						$verb.DoIt()
					}
				}
			}
			#endregion
			
			$CountEnd = $error.Count
			
			return ($CountEnd -eq $CountStart)
		}
		#endregion
	}
	Process
	{
		switch ($ParSet)
		{
			#region Preset Parameterset
			"Preset"
			{
				foreach ($set in $Preset)
				{
					$value = $set.Value__
					$int = @(Convert-FlagsToIntegers $value)
					foreach ($i in $int)
					{
						switch ($i)
						{
							1
							{
								Write-Debug "Creating Shutdown Link"
								New-NW_Link -Name "Herunterfahren" -Target "$env:SystemRoot\System32\shutdown.exe" -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Arguments "-s -t 0" -Icon (New-Object Netzwerker.Utility.IconLocation("$env:SystemRoot\System32\SHELL32.dll", 27)) -PinStart $true -PinTask $false
							}
							2
							{
								Write-Debug "Creating Reboot Link"
								New-NW_Link -Name "Neu Starten" -Target "$env:SystemRoot\System32\shutdown.exe" -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Arguments "-r -t 0" -Icon (New-Object Netzwerker.Utility.IconLocation("$env:SystemRoot\System32\SHELL32.dll", 238)) -PinStart $true -PinTask $false
							}
							4
							{
								Write-Debug "Creating Logoff Link"
								New-NW_Link -Name "Abmelden" -Target "$env:SystemRoot\System32\logoff.exe" -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Arguments " " -Icon (New-Object Netzwerker.Utility.IconLocation("$env:SystemRoot\System32\SHELL32.dll", 44)) -PinStart $true -PinTask $false
							}
						}
					}
				}
			}
			#endregion
			
			#region File Parameterset
			"File"
			{
				foreach ($Target in $ShortcutTarget)
				{
					Write-Debug "Target: $Target"
					# Get Name of shortcut file
					$name = (Get-Item $Target).BaseName
					if ($PSBoundParameters["ShortcutName"]) { $name = $ShortcutName }
					if ($ArgumentsToSourceExe -eq "") { $ArgumentsToSourceExe = " " }
					
					New-NW_Link -Name $name -Target (Get-Item $Target).FullName -Path (Get-Item $ShortcutLocation).FullName -Arguments $ArgumentsToSourceExe -Icon $Icon -PinStart $PinStart -PinTask $PinTask
				}
			}
			#endregion
			
			#region Hardlink Parameterset
			"Hardlink"
			{
				foreach ($Target in $ShortcutTarget)
				{
					if (!(Test-Path $Target -PathType 'Leaf'))
					{
						Write-Debug "[Skip] Invalid Target: $Target"
						Write-Warning "Target must be a valid file! Offender: $Target"
						continue
					}
					
					# Get Name of shortcut file
					$name = (Get-Item $Target).BaseName
					if ($PSBoundParameters["ShortcutName"]) { $name = $ShortcutName }
					
					# Prepare variables
					$Source = (Get-Item $Target).FullName
					$Destination = (Get-Item $ShortcutLocation).FullName + "\" + $name + (Get-Item $Target).Extension
					
					if (Test-Path $Destination)
					{
						Write-Debug "[Skip] Destination for $Target already exists: $Destination"
						Write-Warning "Destination for $Target already exists: $Destination"
						continue
					}
					
					# Do It
					Write-Debug "Hardlinking: $Source to $Destination"
					fsutil.exe hardlink create $Destination $Source
				}
			}
			#endregion Hardlink Parameterset
			
			#region SymLink Parameterset
			"SymLink"
			{
				foreach ($Target in $ShortcutTarget)
				{
					# Get Name of shortcut file
					$name = (Get-Item $Target).BaseName
					if ($PSBoundParameters["ShortcutName"]) { $name = $ShortcutName }
					
					# Prepare variables
					$Source = Get-Item $Target
					$Destination = (Get-Item $ShortcutLocation).FullName + "\" + $name + (Get-Item $Target).Extension
					
					# Do It
					Write-Debug "Creating Symbolic Link or junction: $($Source.FullName) to $Destination"
					[Netzwerker.FileSystem.NTFS.FileSystem]::CreateSymbolicLink($Source, $Destination)
				}
			}
			#endregion SymLink Parameterset
		}
	}
	End
	{
		Write-Debug "[End] Create Shortcuts"
	}
}
New-Alias -Name shortcut -Value New-Shortcut -Scope Global -Option 'AllScope', 'Constant' -Force
New-Alias -Name link -Value New-Shortcut -Scope Global -Option 'AllScope', 'Constant' -Force
#endregion

#region Utility
function Convert-FlagsToIntegers
{
	<#
		.SYNOPSIS
			Converts an int into its component 2-exponent parts.
	
		.DESCRIPTION
			Converts an int into its component 2-exponent parts. This is used to extract information where multiple combinations of options are encoded in a single int, as used in Flags enumerations.
	
		.PARAMETER Integer
			Number to be split into its parts
	
		.EXAMPLE
			PS C:\> 665 | Convert-FlagsToIntegers
	
			This command will return:
			512
			128
			16
			8
			1
			As these powers of 2 make up 665.
	
		.INPUTS
			System.Int32
	
		.OUTPUTS
			System.Int32[]
	
		.NOTES
			Supported Interfaces:
			------------------------
			
			Author:			Friedrich Weinmann
			Company:		die netzwerker Computernetze GmbH
			Created:		11.11.2013
			LastChanged:	19.05.2014
			Version:		1.1
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline)]
		[ValidateScript({ $_ -gt 0 })]
		[int64]
		$Integer
	)
	
	Begin
	{
		# Set the functionname variable
		$fn = (Get-PSCallStack)[0].Command
	}
	
	Process
	{
		foreach ($int in $Integer)
		{
			# Prepare Results variable
			$results = @()
			
			# Store current number into runtime variable
			$num = $int
			
			# Multiply $calc by 2 until it's greater than $num
			$calc = 1
			do
			{
				$calc = $calc * 2
			}
			while ($calc -le $integer)
			
			# Iterate over $calc until $num is 0
			while ($num -gt 0)
			{
				# If $calc is lower than or equal to $num, substract $calc from $num
				if ($calc -le $num)
				{
					$num = $num - $calc
					$results += $calc
				}
				
				# Divide $calc by 2
				$calc = $calc / 2
			}
			
			# Return results
			return $results
		}
	}
	
	End
	{
		
	}
}
#endregion
