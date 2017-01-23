#region Type
$source = @"
using System;

namespace Netzwerker.Utility
{
    public class TNGalleryElement
    {
        public string Title;
        public string Author;
        public Uri Link;

        public string Summary;
        public string[] Tags;
        public int Stars;
        public int Downloads;

        public DateTime Released;
        public DateTime Updated;

        public TNGalleryElement()
        {

        }

        public override string ToString()
        {
            string temp = Author + " : " + Title;
            return temp;
        }
    }
}
"@
Add-Type $source
Remove-Variable "source"
#endregion Type

#region Formating TNGalleryElement
$FormatString = @"
<?xml version="1.0" encoding="utf-16"?>
<Configuration>
<ViewDefinitions>
<View>
  <Name>Netzwerker.Utility.TNGalleryElement</Name>
  <ViewSelectedBy>
    <TypeName>Netzwerker.Utility.TNGalleryElement</TypeName>
  </ViewSelectedBy>
  <TableControl>
    <AutoSize />
    <TableHeaders>
      <TableColumnHeader>
        <Alignment>Right</Alignment>
      </TableColumnHeader>
      <TableColumnHeader>
      </TableColumnHeader>
      <TableColumnHeader>
        <Label>S</Label>
      </TableColumnHeader>
      <TableColumnHeader>
        <Label>DLs</Label>
        <Alignment>Right</Alignment>
      </TableColumnHeader>
      <TableColumnHeader>
      </TableColumnHeader>
      <TableColumnHeader>
      </TableColumnHeader>
      <TableColumnHeader>
      </TableColumnHeader>
    </TableHeaders>
    <TableRowEntries>
      <TableRowEntry>
        <TableColumnItems>
          <TableColumnItem>
            <PropertyName>Author</PropertyName>
          </TableColumnItem>
          <TableColumnItem>
            <PropertyName>Title</PropertyName>
          </TableColumnItem>
		  <TableColumnItem>
            <PropertyName>Stars</PropertyName>
          </TableColumnItem>
          <TableColumnItem>
            <PropertyName>Downloads</PropertyName>
          </TableColumnItem>
          <TableColumnItem>
            <PropertyName>Released</PropertyName>
            <FormatString>{0:dd} {0:MMM}, {0:yyyy}</FormatString>
          </TableColumnItem>
          <TableColumnItem>
            <PropertyName>Updated</PropertyName>
            <FormatString>{0:dd} {0:MMM}, {0:yyyy}</FormatString>
          </TableColumnItem>
          <TableColumnItem>
            <PropertyName>Link</PropertyName>
          </TableColumnItem>
        </TableColumnItems>
      </TableRowEntry>
    </TableRowEntries>
  </TableControl>
</View>
</ViewDefinitions>
</Configuration>
"@

$FormatString | Set-Content ($env:TEMP + "\Get-TechnetRepository.Format.ps1xml") -Encoding 'UTF8'
Update-FormatData -AppendPath ($env:TEMP + "\Get-TechnetRepository.Format.ps1xml")
Remove-Variable "FormatString"
#endregion Formating TNGalleryElement

#region Function
function Get-TechnetRepository
{
	<#
		.SYNOPSIS
			Performs a technet gallery query, searching for scripts.
		
		.DESCRIPTION
			Performs a technet gallery query, searching for scripts.
			The filters are additive and ALL need to be met. For detailed description of individual filters, see their respective filters.
	
			Note: It does NOT download the scripts, however it will provide a link to the Gallery page from which to load it.
		
		.PARAMETER Author
			The author(s) of scripts to be searched. Requires exact match, one query per user will be launched.
		
		.PARAMETER Contributor
			The Contributor in the technet gallery is the category the Author belongs to.
			Known Contributors at the time of this writing:
			Community, Microsoft, Exchange Team, Office Team
		
		.PARAMETER  NoRes
			Internal Use Only
		
		.PARAMETER ProgrammingLanguage
			Options: Powershell, VBS, SQL, JavaScript, Python, VB
			This is the scripting language used. VB.NET is covered by VB.
			Languages as filters are additive (e.g.: If Powershell and VBS are specified, all scripts that are written in either language will be listed).
	
		.PARAMETER Query
			The search Query (as if typed into the grey search bar).
		
		.PARAMETER RootCategory
			The Root Category to which the script belongs to (e.g.: Active Directory).
			Note that not all categories are using their display name as search name.
			In case of doubt, check the Gallery, select the category and check for what's behind ".Value=" in the addressbar.
			Root Categories have no whitespaces. All Input whitespaces will be removed.
		
		.PARAMETER SubCategory
			The SubCategory to which the script belongs to (e.g.: Computer Accounts).
			The same naming restrictions (and conveniences) as with Root Categories apply.
		
		.PARAMETER SupportedPlatform
			The Operating System that is supported. Unreliable since many authors do not flag reliably.
			The Naming conventions are non-transparent, in case of doubt check manually.
		
		.PARAMETER Tag
			The tags the script has. Note, that ALL tags must be met.
		
		.EXAMPLE
			PS C:\> Get-TechnetRepository -Author "FWN"
	
			Returns all published scripts by the author of this function.
		
		.NOTES
			Supported Interfaces:
			------------------------
			Result Caching Interface
			Stores full Result
			------------------------
			
			Author:       Friedrich Weinmann
			Company:      die netzwerker Computernetze GmbH
			Created:      03.07.2014
			LastChanged:  02.09.2014
			Version:      1.2
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Position = 0)]
		[String]
		$Query,
		
		[String[]]
		$Author,
		
		[string]
		$RootCategory,
		
		[string]
		$SubCategory,
		
		[ValidateSet('Powershell', 'VBS', 'SQL', 'JavaScript', 'Python', 'VB')]
		[string[]]
		$ProgrammingLanguage,
		
		[string[]]
		$Contributor,
		
		[string[]]
		$Tag,
		
		[string]
		$SupportedPlatform,
		
		[switch]
		$NoRes,
		
		[switch]
		$Force
	)
	
	Begin
	{
		#region Process links
		
		# Runtime Variables for Processing Link-Creation
		$WebLinks = @()
		$count = 0
		$root = "http://gallery.technet.microsoft.com/site/search?"
		
		# Manage Query
		if ($PSBoundParameters["Query"])
		{
			if ($count -gt 0) { $root += "&" }
			$root += "f[$count].Type=SearchText&f[$count].Value=Query"
			$count++
		}
		
		# Manage Root Category
		if ($PSBoundParameters["RootCategory"])
		{
			if ($count -gt 0) { $root += "&" }
			$root += "f[$count].Type=RootCategory&f[$count].Value=" + $RootCategory.Replace(" ", "")
			$count++
		}
		
		# Manage Sub Category
		if ($PSBoundParameters["SubCategory"])
		{
			if ($count -gt 0) { $root += "&" }
			$root += "f[$count].Type=SubCategory&f[$count].Value=$SubCategory"
			$count++
		}
		
		# Manage Programming Languages
		if ($PSBoundParameters["ProgrammingLanguage"])
		{
			foreach ($Language in $ProgrammingLanguage)
			{
				if ($count -gt 0) { $root += "&" }
				$root += "f[$count].Type=ProgrammingLanguage&f[$count].Value=$ProgrammingLanguage"
				$count++
			}
		}
		
		# Manage Contributors
		if ($PSBoundParameters["Contributor"])
		{
			foreach ($T in $Tag)
			{
				if ($count -gt 0) { $root += "&" }
				$root += "f[$count].Type=Contributors&f[$count].Value=$Con"
				$count++
			}
		}
		
		# Manage Tags
		if ($PSBoundParameters["Tag"])
		{
			foreach ($Con in $Contributor)
			{
				if ($count -gt 0) { $root += "&" }
				$root += "f[$count].Type=Tag&f[$count].Value=$T"
				$count++
			}
		}
		
		# Manage Supported Platform
		if ($PSBoundParameters["SupportedPlatform"])
		{
			if ($count -gt 0) { $root += "&" }
			$root += "f[$count].Type=SupportedPlatform&f[$count].Value=$SupportedPlatform"
			$count++
		}
		
		# Manage Authors
		if ($PSBoundParameters["Author"])
		{
			foreach ($A in $Author)
			{
				if ($count -gt 0) { $root += "&" }
				$WebLinks += $root + "f[$count].Type=User&f[$count].Value=$A"
				$count++
			}
		}
		else { $WebLinks += $root }
		
		# Manage Force
		if (($Count -eq 0) -and !$force)
		{
			Write-Warning "Interrupting execution: No search filter defined. Use -Force Parameter to force loading ALL gallery elements."
			$Interrupt = $true
		}
		<#
		$root = "http://gallery.technet.microsoft.com/site/search?"
		
		Pair:
		f[x].Type=ABC
		f[x].Value=DEF
		Start counting x at 0
		Combine string with "&" (except after root)
		
		Valid Types:
		ProgrammingLanguage # MultiSelectable
		User
		RootCategory
		SubCategory
		SupportedPlatform
		Contributors # MultiSelectable
		SearchText
		Tag
		#>
		#endregion Process links
		
		#region Functions
		function Process-Data
		{
			Param (
				$Data
			)
			
			# Prepare return object
			$Results = @()
			
			#region Process input to filter out the raw data
			# Cut off preliminary overhead
			$content = $Data.SubString($content.IndexOf('<tr class="itemRow">'))
			
			# Collect raw data
			$RawData = @()
			
			while ($content.Contains('<tr class="itemRow">'))
			{
				# Ensure later iterations don't have leftover crap
				$content = $content.SubString($content.IndexOf('<tr class="itemRow">'))
				
				# Extract raw data
				$temp = $content.SubString(0, ($content.IndexOf('</tr>') + 5))
				
				# Add Raw Data to collection
				$RawData += $temp
				
				# Cull $content by length of temp
				$content = $content.SubString($temp.length)
			}
			#endregion Process input to filter out the raw data
			
			#region Process Data
			foreach ($item in $RawData)
			{
				# Create object
				$obj = New-Object Netzwerker.Utility.TNGalleryElement
				
				# Process Link
				$LinkA = $item.IndexOf('href="') + 6
				$LinkB = $item.IndexOf('"', $LinkA)
				$obj.Link = "http://gallery.technet.microsoft.com" + $item.SubString($LinkA, ($LinkB - $LinkA))
				
				# Process Title
				$TitleA = $LinkB + 20
				$TitleB = $item.IndexOf("`n", $TitleA)
				$obj.Title = $item.SubString($TitleA, ($TitleB - $TitleA)).Replace("<wbr />", "").Trim()
				
				# Process Summary
				$SummaryA = $item.IndexOf("`n", ($item.IndexOf('<div class="summaryBox">'))) + 13
				$SummaryB = $item.IndexOf("`n", $SummaryA)
				$obj.Summary = $item.SubString($SummaryA, ($SummaryB - $SummaryA)).Replace("<br />", "`n").Replace("<wbr />", "").Trim()
				
				# Process Updated
				$UpdatedA = $item.IndexOf("            Updated") + 20
				$UpdatedB = $item.IndexOf("`n", $UpdatedA)
				$temp = $item.SubString($UpdatedA, ($UpdatedB - $UpdatedA)).Trim().Trim().Split("/")
				$obj.Updated = Get-Date -Year $temp[2] -Month $temp[0] -Day $temp[1] -Hour 0 -Minute 0 -Second 0
				
				# Process Released
				$ReleasedA = $item.IndexOf("            Released") + 21
				$ReleasedB = $item.IndexOf("`n", $ReleasedA)
				$temp = $item.SubString($ReleasedA, ($ReleasedB - $ReleasedA)).Trim().Split("/")
				$obj.Released = Get-Date -Year $temp[2] -Month $temp[0] -Day $temp[1] -Hour 0 -Minute 0 -Second 0
				
				# Process Author
				$NameA = $item.IndexOf(">", $item.IndexOf("profile-usercard-customLink")) + 1
				$NameB = $item.IndexOf("`n", $NameA)
				$obj.Author = $item.SubString($NameA, ($NameB - $NameA)).Trim()
				
				# Process Tags
				$TagsA = $item.IndexOf('<div id="Tags">') + 29
				$TagsB = $item.IndexOf("`n", $TagsA)
				$TagsRaw = @($item.SubString($TagsA, ($TagsB - $TagsA)).Split(">"))
				$obj.Tags = $TagsRaw | Where { $_ -like "*</a" } | %{ $_ -split "<" | Select -First 1 }
				
				# Process Stars
				$obj.Stars = 5 - ($item | Select-String -Pattern 'class="EmptyRatingStar"' -AllMatches | Select -ExpandProperty Matches | measure | Select -ExpandProperty Count)
				
				# Process Downloads
				if (($item | Select-String -Pattern "Downloads            </div>" | Select -ExpandProperty Matches | measure).Count -gt 0)
				{
					$i = $item | Select-String -Pattern "Downloads            </div>" | select -ExpandProperty Matches | select -ExpandProperty Index
					[int]$obj.Downloads = $item.SubString(($i - 12), 10).Trim()
				}
				
				# Store to output
				$Results += $obj
			}
			#endregion Process Data
			
			return $Results
		}
		#endregion Functions
		
		# Create WebClient
		$WebClient = New-Object System.Net.WebClient
		
		# Declare storage variable
		$Results = @()
	}
	Process
	{
		if ($Interrupt) { return }
		foreach ($WebLink in $WebLinks)
		{
			#region For each Weblink
			
			# Runtime Variables
			$int = 1
			$test = $true
			
			while ($test)
			{
				# Get Content
				$content = $WebClient.DownloadString("$WebLink&pageIndex=$int")
				
				# Validate input
				if ($content.IndexOf('<tr class="itemRow">') -eq -1) { $test = $false; break }
				
				# Process Information
				$Results += Process-Data -Data $content
				
				# Increment Counter (get next page)
				$int++
			}
			
			#endregion For each Weblink
		}
	}
	End
	{
		# Return Results
		if (!$NoRes) { $script:NW_Result = $Results }
		return $Results
	}
}
#endregion Function
