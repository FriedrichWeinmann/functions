#region Network Library
$source = @"
using System;
using System.Net;
using System.Net.NetworkInformation;

namespace FWN
{
    namespace Network
    {
        public class PingReply
        {
            public IPAddress address;
            public int RoundtripTime;

            public PingReply(IPAddress address, int RoundtripTime)
            {
                this.address = address;
                this.RoundtripTime = RoundtripTime;
            }

            public override string ToString()
            {
                string temp = "" + address.ToString() + " Rtt: " + RoundtripTime;
                return temp;
            }
        }

        public class PingReport
        {
            public IPAddress Address;
            public string Target;
            public PingReportResult Result;
            public PingReportMath Evaluation;
            public string Name;
            public PingReportOptions Options;

            public PingReport()
            {

            }

            public override string ToString()
            {
                string temp = "" + Address.ToString() + " " + Result;
                return temp;
            }
        }

        public class PingReportOptions
        {
            public int TTL;
            public int Wait;
            public int Number;
            public bool ResolveName;

            public override string ToString()
            {
                string temp = "Number: " + Number + ", TTL: " + TTL + ", Wait: " + Wait + ", Resolve Name: ";
                if (ResolveName) { temp = temp + "True"; }
                else { temp = temp + "False"; }
                return temp;
            }
        }

        public class PingReportMath
        {
            public double RoundTripAverage;
            public int RoundTripTotal;
            public int RoundTripMax;
            public int RoundTripMin;
            public int[] RoundTrips;
            public double RoundTripVariance;
            public double RoundTripStandardDeviation;
            public string RoundTripDeviationPercentage;
            public double RoundTripAbsoluteDeviation;
            public string RoundTripAbsDevPercentage;

            public override string ToString()
            {
                string temp = "Average: " + RoundTripAverage + ", Standard: " + RoundTripDeviationPercentage + "%" + ", Absolute: " + RoundTripAbsDevPercentage + "%";
                return temp;
            }
        }

        public class PingReportResult
        {
            public int Success;
            public int Lost;
            public int Total;
            public int SuccessPercent;
            public IPStatus[] Errors;
            public double RoundTripAverage;
            public int RoundTripTotal;

            public override string ToString()
            {
                string temp = "Sent: " + Total + ", Percent returned: " + SuccessPercent + ", Av. Time: " + RoundTripAverage;
                return temp;
            }
        }

        public enum PingSoundOption
        {
            Silent = 1,
            UntilFound = 2,
            UntilNotFound = 4,
            AfterFound = 8,
            AfterNotFound = 16,
            AlwaysFound = 32,
            AlwaysNotFound = 64,
            Always = 128,
        }
    }
}
"@
Add-Type $source
Remove-Variable "source"
#endregion

#region Utility
function Cut-Number
{
	<#
		.SYNOPSIS
			Cuts away decimals, leaving behind the number of decimals specified.
	
		.DESCRIPTION
			Cuts away decimals, leaving behind the number of decimals specified. Will not accept numbers with a "," to seperate decimals.
	
		.PARAMETER number
			Parameter that will be truncated (double)
	
		.PARAMETER decimals
			how many decimals will be left, defaults to 0
	
		.EXAMPLE example1
			Cut-Number 2.456 2
			Will return 2.45
	#>
	Param(
		[Parameter(Position=0, Mandatory=$True)]
		[double]
		$Number,
	
		[Parameter(Position=1)]
		[int]
		$Decimals = 0
	)
	
	$factor = 1
	$i = 0
	While ($i -lt $decimals)
	{
		$factor = $factor * 10
		$i++
	}
	
	$num = $number * $factor
	$result = [System.math]::Truncate($num) / $factor
	
	return $result
}
#endregion

#region Main function
function Send-Ping 
{ 
    <# 
		.SYNOPSIS 
		    Sends any number of pings at a target, analyzing round trip time. Does not have wait between pings. 

		.DESCRIPTION 
		    Sends any number of pings at a target, analyzing round trip time. Does not have wait between pings. 
		    It is possible to add a wait period (in seconds or milliseconds) inbetween pings. 

		.PARAMETER Target
		    The target adress of your ping 

		.PARAMETER Number
			Alias: n
		    The number of pings you want to send 

		.PARAMETER Ttl
			Alias: i
		    The time to live for each individual ping. In seconds, unless the msec switch has been set (then in milliseconds)

		.PARAMETER Wait
			Alias: w
		    The time to wait between each individual ping. In seconds, unless the msec switch has been set (then in milliseconds)

		.PARAMETER Msec
			Switch. If set, all time parameters (ttl and wait) will be read as milliseonds instead of seconds.

		.PARAMETER GetName
			Alias: a
			Switch. If set, the function tries to resolve the name in a DNS-Query
	
		.PARAMETER Endless
			Alias: t
			Switch. If set, the function will keep on pinging.
			Setting this function will set a wait between pings
			of 1 second unless another has been defined.
			It will also toggle the Announce switch, giving
			constant feedback after each ping.
	
		.PARAMETER Announce
			Alias: v
			Switch. If set, the function will write feedback into
			the shell after each ping.
	
		.PARAMETER SoundOption
			Alias: s
			The SoundOption Parameter configures how accoustical
			feedback is given. This can be useful for giving notification
			on connectivitychanges without visually monitoring the shell.
	
		.PARAMETER SoundAfterCounter
			How often a notification is sounded after the registered
			statuschange (only works for SoundOptions AfterFound and
			AfterNotFound). Set to a negative value for infinite
			accoustical feedback.
	
		.PARAMETER NoRes
			Switch. Internal use only
	
		.OUTPUTS
			Netzwerker.Network.PingReport

		.NOTES 
		    Author: 		Friedrich Weinmann 
		    Created on: 	22.10.2013
			Last modified: 	23.10.2013
			Version: 		1.1
    #> 
    [CmdletBinding()] 
    Param( 
        [Parameter(Mandatory=$true, Position=0)] 
        [string] 
        $Target, 
     
        [Parameter(Position=1)]
		[Alias('n')]
        [int] 
        $Number = 1, 
         
        [Parameter(Position=2)] 
		[Alias('i')]
        [int] 
        $Ttl, 
     
        [Parameter(Position=3)]
		[Alias('w')]
        [int] 
        $Wait = 0,
	
		[switch]
		$Msec,
	
		[switch]
		[Alias('a')]
		$GetName,
	
		[switch]
		[Alias('t')]
		$Endless,
	
		[switch]
		[Alias('v')]
		$Announce,
	
		[FWN.Network.PingSoundOption]
		[Alias('s')]
		$SoundOption = [FWN.Network.PingSoundOption]::Silent,
	
		[int]
		[Alias('sac')]
		$SoundAfterCounter = 5
    )
	
	#region Ping preparation
	# Configure Infinite Ping
	if ($Endless)
	{
		if (($Wait -eq 0) -and ($Msec)){$Wait = 1000}
		elseif ($Wait -eq 0){$Wait = 1}
		$Number = -1
		$Announce = $true
	}
     
    # Declare variables to gather results 
    $success = 0 
    $fail = 0 
    $roundtripCol = @() 
    $failures = @()
	[string]$answerIP = ""
     
    # Prepare sleep value
	if ($msec){$sleep = $wait}
	else {$sleep = $wait * 1000}
    if ($sleep -lt 0){$sleep = 0}
	
    # Prepare ping
    $ping = New-Object System.Net.NetworkInformation.Ping 
    if ($ttl -eq 0){$ttlfinished = 3000}
	elseif ($msec){$ttlfinished = $ttl}
	else {$ttlfinished = $ttl * 1000}
	if ($Number -lt 1){$Number = 1}
	
	# Prepare Sound Options
	if ($SoundOption -ne [FWN.Network.PingSoundOption]::Silent)
	{
		if ($SoundOption -like "UntilFound"){$S_UntilFound = $true}
		if ($SoundOption -like "UntilNotFound"){$S_UntilNotFound = $true}
		if ($SoundOption -like "AfterFound"){$S_AfterFound = $true}
		if ($SoundOption -like "AfterNotFound"){$S_AfterNotFound = $true}
		if ($SoundOption -like "AlwaysFound"){$S_AlwaysFound = $true}
		if ($SoundOption -like "AlwaysNotFound"){$S_AlwaysNotFound = $true}
		if ($SoundOption -like "Always"){$S_Always = $true}
	}
	$Did_Succeed = $false
	$Did_Fail = $false
    
	# Ping iteration counter
    $i = 0
	#endregion
	
	#region sending Pings
	if (!$Endless){Write-Progress -Activity "Pinging..." -Status "Pinging..." -CurrentOperation "Sending more pings" -PercentComplete 0}
	
	# Send pings
    while (($i -lt $number) -or $Endless)
    {
		# Set sound option
		$S_Ring = $false
		
		# Try sending the ping
        Try
		{
			$answer = $ping.Send($target,$ttlfinished)
		}
		# Interrupt function if the method throws an error (which it does, when a parameter was given that is neither an IP Address nore a resolveable DNS name)
		Catch
		{
			if ($_.Exception.InnerException.InnerException.Message -eq "Der angegebene Host ist unbekannt"){Write-Warning ("Unknown host: " + $target)}
			else {Write-Warning "Unknown Error, terminating"}
			break break
		}
		
		# Check whether this was the last ping
        $islastping = (($number - $i) -eq 1)
		
		# Handle Always sound rule
		if ($S_Always){$S_Ring = $true}
		
		# If ping was successfull
        if ($answer.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) 
        {
			# Do standard recordings
            $success++ 
            $roundtripCol += $answer.RoundtripTime
			$answerIP = $answer.Address
			
			# Handle sound events
			$Did_Succeed = $true
			if ($S_AlwaysFound){$S_Ring = $true}
			if ($S_AfterFound -and ($SoundAfterCounter -ne 0))
			{
				$S_Ring = $true
				$SoundAfterCounter--
			}
			if ($S_UntilNotFound -and (!$Did_Fail)){$S_Ring = $true}
			
			# Ring a sound
			if ($S_Ring){[System.Media.SystemSounds]::Beep.Play()}
			
			# Handle Announce settings
			if ($Announce){Write-Host ("Response from " + $answer.Address + " Bytes=" + $answer.Buffer.Length + " RTT: " + $answer.RoundtripTime + "ms TTL=" + $ttlfinished + "ms")}
			
			# Handle sleeping 
			if (!$islastping)
			{
				$sleeptemp = $sleep - $answer.RoundtripTime
				if ($sleeptemp -lt 0){$sleeptemp = 0}
				[System.Threading.Thread]::Sleep($sleeptemp)
			}
        }
		# If ping was not successfull
        else 
        {
			# Do standard recordings
            $fail++
            $failures += $answer.Status
			
			# Handle Sound events
			$Did_Fail = $true
			if ($S_AlwaysNotFound){$S_Ring = $true}
			if ($S_AfterNotFound -and ($SoundAfterCounter -ne 0))
			{
				$S_Ring = $true
				$SoundAfterCounter--
			}
			if ($S_UntilNotFound -and (!$Did_Succeed)){$S_Ring = $true}
			
			# Ring a sound
			if ($S_Ring){[System.Media.SystemSounds]::Beep.Play()}
			
			# Handle Announce settings
			if ($Announce){Write-Host ("No response, " + $answer.Status)}
			
			# Handle sleeping
			if (!$islastping)
			{
				$sleeptemp = $sleep - $ttl
				if ($sleeptemp -lt 0){$sleeptemp = 0}
				[System.Threading.Thread]::Sleep($sleeptemp)
			}
        } 
        
		# Increase counter
        $i++
		
		# Report Progress
		if (!$Endless)
		{
	        [int]$progress = [System.Math]::Truncate(($i / $number) * 100)
	        Write-Progress -Activity "Pinging..." -Status "Pinging..." -CurrentOperation "Sending more pings" -PercentComplete $progress
		}
    } 
    Write-Progress -Activity "Pinging..." -Status "Pinging..." -CurrentOperation "Finished" -Completed 
    #endregion
	
	#region Post-Process ping
    # Analyze roundtrips 
    $roundtriptotal = 0 
    
    foreach ($trip in $roundtripCol) 
    { 
        $roundtriptotal += $trip 
        if (($trip -lt $roundtripmin) -or ($roundtripmin -eq $null)){$roundtripmin = $trip} 
        if (($trip -gt $roundtripmax) -or ($roundtripmax -eq $null)){$roundtripmax = $trip} 
    } 
    if ($roundtripCol.Length -gt 0){$roundtripav = $roundtriptotal / $roundtripCol.Length}
     
    # Calculate variance 
    if ($roundtripCol.Length -gt 1) 
    { 
        $f = 1 / ($roundtripCol.Length - 1) 
        $b = 0 
        foreach ($trip in $roundtripCol){$b = $b + (($trip - $roundtripav) * ($trip - $roundtripav))} 
        $roundtripVariance = $b * $f 
    }
	
	# Calculate deviation
	if ($roundtripVariance -ge 0){$deviation = [System.Math]::Sqrt($roundtripVariance)}
	else {$deviation = 0}
	if ($roundtripav -gt 0){$devPercent = ($deviation / $roundtripav) * 100}
	else {$devPercent = 0}
	
	# Calculate Absolute and relative Absolute deviation
	if ($success -gt 0)
	{
		$t = 0
		foreach ($trip in $roundtripCol)
		{
			$temp = $trip - $roundtripav
			if ($temp -lt 0){$temp = $temp * -1}
			$t += $temp
		}
		$AbsoluteDeviation = $t / $roundtripCol.Length
		if ($roundtripav -gt 0){$AbsoluteDeviationPercent = ($AbsoluteDeviation / $roundtripav) * 100}
		else {$AbsoluteDeviationPercent = 0}
	}
	
	# Get name if requested
	if ($getname)
	{
		try
		{
			$name = ([System.Net.Dns]::GetHostByAddress($answerIP)).HostName
		}
		Catch
		{
			$name = "Could not resolve name"
		}
	}
	#endregion
     
    #region Build response object
	
	# First the static result set
	$PingResult = New-Object FWN.Network.PingReportResult
	$PingResult.Success				= $success
	$PingResult.Lost				= $fail
	$PingResult.Total				= $Number
	$PingResult.SuccessPercent		= Cut-Number -number (($success / $Number) * 100)
	$PingResult.Errors				= $failures
	$PingResult.RoundTripAverage	= $roundtripav
	$PingResult.RoundTripTotal		= $roundtriptotal
	
	# Then the mathematic evaluation
	$PingEvaluation = New-Object FWN.Network.PingReportMath
	$PingEvaluation.RoundTripAverage				= Cut-Number -number $roundtripav -decimals 4
	$PingEvaluation.RoundTripTotal					= $roundtriptotal
	$PingEvaluation.RoundTripMax					= $roundtripmax
	$PingEvaluation.RoundTripMin					= $roundtripmin
	$PingEvaluation.RoundTrips						= $roundtripCol
	$PingEvaluation.RoundTripVariance				= Cut-Number -number $roundtripVariance -decimals 4
	$PingEvaluation.RoundTripStandardDeviation		= Cut-Number -number $deviation -decimals 4
	$PingEvaluation.RoundTripDeviationPercentage	= Cut-Number -number $devPercent -decimals 1
	$PingEvaluation.RoundTripAbsoluteDeviation		= Cut-Number -number $AbsoluteDeviation -decimals 4
	$PingEvaluation.RoundTripAbsDevPercentage		= Cut-Number -number $AbsoluteDeviationPercent -decimals 1
	
	# Then the object containing the parameters
	$PingOptions = New-Object FWN.Network.PingReportOptions
	$PingOptions.TTL			= $ttlfinished
	$PingOptions.Wait			= $sleep
	$PingOptions.Number			= $Number
	$PingOptions.ResolveName	= $GetName
	
	# Finally build the report, containing the final result
	$result = New-Object FWN.Network.PingReport
	$result.Target		= $Target
	$result.Result		= $PingResult
	$result.Evaluation	= $PingEvaluation
	$result.Options		= $PingOptions
	if (($answerIP -ne $null) -and ($answerIP -ne "")){$result.Address = $answerIP}
	if ($name -ne $null){$result.Name = $name}
	#endregion
	
	# Return result
    return $result
}
New-Alias -Name Ping -Value Send-Ping -Scope Global -Option 'AllScope', 'Constant'
#endregion
