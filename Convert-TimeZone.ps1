function Convert-TimeZone
{
	<#
		.SYNOPSIS
			Converts a DateTime object from one Timezone to another.
		
		.DESCRIPTION
			Converts a DateTime object from one Timezone to another.
		
		.PARAMETER Date
			Default: Get-Date
			The DateTime-object(s) to convert.
		
		.PARAMETER From
			Default: Local Timezone
			The originating Timezone.
	
			Note: Argument needs to be wrapped in apostrophes. Eg: "Pacific Standard Time"
		
		.PARAMETER To
			Default: UTC
			The Destination Timezone
	
			Note: Argument needs to be wrapped in apostrophes. Eg: "Pacific Standard Time"
		
		.EXAMPLE
			PS C:\> Convert-TimeZone
	
			Converts the current DateTime to Utc.
	
		.EXAMPLE
			PS C:\> Convert-TimeZone -Date (Get-Date -Hour 6 -Minute 0 -Second 0) -From "Pacific Standard Time" -To "W. Europe Standard Time"
	
			Returns the time it will be in Western Europe (Amsterdam, Berlin, Bern, Rome, Vienna, etc.), when it's 6am in the Pacific Standard Time Zone (Los Angeles, San Francisco, etc.).
		
		.NOTES
			Supported Interfaces:
			------------------------
			Debug Interface
			- Debug-Level: 9
			------------------------
			
			Author:       Friedrich Weinmann
			Company:      die netzwerker Computernetze GmbH
			Created:      05.12.2014
			LastChanged:  05.12.2014
			Version:      1.0
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Position = 0, ValueFromPipeline = $true)]
		[System.DateTime]
		$Date = (Get-Date),
		
		[ValidateSet("Dateline Standard Time", "UTC-11", "Hawaiian Standard Time", "Alaskan Standard Time", "Pacific Standard Time (Mexico)", "Pacific Standard Time", "US Mountain Standard Time", "Mountain Standard Time (Mexico)", "Mountain Standard Time", "Central Standard Time", "Central Standard Time (Mexico)", "Central America Standard Time", "Canada Central Standard Time", "SA Pacific Standard Time", "Eastern Standard Time", "US Eastern Standard Time", "Venezuela Standard Time", "Paraguay Standard Time", "Atlantic Standard Time", "Central Brazilian Standard Time", "SA Western Standard Time", "Pacific SA Standard Time", "Newfoundland Standard Time", "E. South America Standard Time", "Argentina Standard Time", "SA Eastern Standard Time", "Greenland Standard Time", "Montevideo Standard Time", "Bahia Standard Time", "UTC-02", "Mid-Atlantic Standard Time", "Azores Standard Time", "Cape Verde Standard Time", "Morocco Standard Time", "GMT Standard Time", "UTC", "Greenwich Standard Time", "W. Europe Standard Time", "Central Europe Standard Time", "Romance Standard Time", "Central European Standard Time", "W. Central Africa Standard Time", "Namibia Standard Time", "GTB Standard Time", "Middle East Standard Time", "Syria Standard Time", "South Africa Standard Time", "FLE Standard Time", "Turkey Standard Time", "Israel Standard Time", "Egypt Standard Time", "E. Europe Standard Time", "Libya Standard Time", "Jordan Standard Time", "Arabic Standard Time", "Kaliningrad Standard Time", "Arab Standard Time", "E. Africa Standard Time", "Iran Standard Time", "Arabian Standard Time", "Azerbaijan Standard Time", "Caucasus Standard Time", "Russian Standard Time", "Mauritius Standard Time", "Georgian Standard Time", "Afghanistan Standard Time", "West Asia Standard Time", "Pakistan Standard Time", "India Standard Time", "Sri Lanka Standard Time", "Nepal Standard Time", "Central Asia Standard Time", "Bangladesh Standard Time", "Ekaterinburg Standard Time", "Myanmar Standard Time", "SE Asia Standard Time", "N. Central Asia Standard Time", "North Asia Standard Time", "Singapore Standard Time", "China Standard Time", "W. Australia Standard Time", "Taipei Standard Time", "Ulaanbaatar Standard Time", "North Asia East Standard Time", "Tokyo Standard Time", "Korea Standard Time", "Cen. Australia Standard Time", "AUS Central Standard Time", "E. Australia Standard Time", "AUS Eastern Standard Time", "West Pacific Standard Time", "Tasmania Standard Time", "Yakutsk Standard Time", "Central Pacific Standard Time", "Vladivostok Standard Time", "New Zealand Standard Time", "Fiji Standard Time", "UTC+12", "Magadan Standard Time", "Kamchatka Standard Time", "Tonga Standard Time", "Samoa Standard Time")]
		[string]
		$From = ([System.TimeZoneInfo]::Local.Id),
		
		[ValidateSet("Dateline Standard Time", "UTC-11", "Hawaiian Standard Time", "Alaskan Standard Time", "Pacific Standard Time (Mexico)", "Pacific Standard Time", "US Mountain Standard Time", "Mountain Standard Time (Mexico)", "Mountain Standard Time", "Central Standard Time", "Central Standard Time (Mexico)", "Central America Standard Time", "Canada Central Standard Time", "SA Pacific Standard Time", "Eastern Standard Time", "US Eastern Standard Time", "Venezuela Standard Time", "Paraguay Standard Time", "Atlantic Standard Time", "Central Brazilian Standard Time", "SA Western Standard Time", "Pacific SA Standard Time", "Newfoundland Standard Time", "E. South America Standard Time", "Argentina Standard Time", "SA Eastern Standard Time", "Greenland Standard Time", "Montevideo Standard Time", "Bahia Standard Time", "UTC-02", "Mid-Atlantic Standard Time", "Azores Standard Time", "Cape Verde Standard Time", "Morocco Standard Time", "GMT Standard Time", "UTC", "Greenwich Standard Time", "W. Europe Standard Time", "Central Europe Standard Time", "Romance Standard Time", "Central European Standard Time", "W. Central Africa Standard Time", "Namibia Standard Time", "GTB Standard Time", "Middle East Standard Time", "Syria Standard Time", "South Africa Standard Time", "FLE Standard Time", "Turkey Standard Time", "Israel Standard Time", "Egypt Standard Time", "E. Europe Standard Time", "Libya Standard Time", "Jordan Standard Time", "Arabic Standard Time", "Kaliningrad Standard Time", "Arab Standard Time", "E. Africa Standard Time", "Iran Standard Time", "Arabian Standard Time", "Azerbaijan Standard Time", "Caucasus Standard Time", "Russian Standard Time", "Mauritius Standard Time", "Georgian Standard Time", "Afghanistan Standard Time", "West Asia Standard Time", "Pakistan Standard Time", "India Standard Time", "Sri Lanka Standard Time", "Nepal Standard Time", "Central Asia Standard Time", "Bangladesh Standard Time", "Ekaterinburg Standard Time", "Myanmar Standard Time", "SE Asia Standard Time", "N. Central Asia Standard Time", "North Asia Standard Time", "Singapore Standard Time", "China Standard Time", "W. Australia Standard Time", "Taipei Standard Time", "Ulaanbaatar Standard Time", "North Asia East Standard Time", "Tokyo Standard Time", "Korea Standard Time", "Cen. Australia Standard Time", "AUS Central Standard Time", "E. Australia Standard Time", "AUS Eastern Standard Time", "West Pacific Standard Time", "Tasmania Standard Time", "Yakutsk Standard Time", "Central Pacific Standard Time", "Vladivostok Standard Time", "New Zealand Standard Time", "Fiji Standard Time", "UTC+12", "Magadan Standard Time", "Kamchatka Standard Time", "Tonga Standard Time", "Samoa Standard Time")]
		[string]
		$To = "UTC"
	)
	
	Begin
	{
		# Write obening Line
		Write-Debug "[Start] [Converting Timezones]"
	}
	Process
	{
		foreach ($D in $Date)
		{
			$D = [System.DateTime]::SpecifyKind($D, "Unspecified")
			$FromTemp = [System.TimeZoneInfo]::FindSystemTimeZoneById($From)
			$ToTemp = [System.TimeZoneInfo]::FindSystemTimeZoneById($To)
			$Utc = [System.TimeZoneInfo]::ConvertTimeToUtc($D, $FromTemp)
			[System.TimeZoneInfo]::ConvertTimeFromUtc($Utc, $ToTemp)
		}
	}
	End
	{
		# Write closing line
		Write-Debug "[End] [Converting Timezones]"
	}

}
