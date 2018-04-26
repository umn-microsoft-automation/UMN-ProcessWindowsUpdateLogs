# ProcessLatestWindowsUpdateLogs.ps1
# By Craig Woodford (craigw@umn.edu)
# Last update 4/26/2018

###
# Copyright 2017 University of Minnesota, Office of Information Technology

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
###

# This script is used to convert Windows Update logs for Server 2016 systems
# into text-based logs for ingestion into a SIEM system such as Splunk. The
# script is designed to run on a regular basis so that only logs that have not
# been converted since the last script run-time are processed. The script needs
# to be run with administrative rights.

# Windows update ETL log files location (default: C:\Windows\Logs\WindowsUpdate).
$logPath = "C:\Windows\Logs\WindowsUpdate"

# Path of the file that will contain the last run time.
$runTimePath = "C:\Scripts\powershell-scratch\fileread_example.txt"

# Path for the Windows update log file (this file will be overwritten with each run).
$outputPath = "C:\Scratch\WindowsUpdate.log"

# Windows Event Log source name.
$eventLogSourceName = "MPT-GetLatestWindowsUpdateLogs.ps1"

# Windows build number - the script will only run for build numbers greater then provided.
# The windows 10 RTM build number is 10240.
$earliestBuildtoRun = 10240

function Invoke-ProcessLatestWindowsUpdateLogs {
<#
.Synopsis
   Builds the Windows update logs since the last time the function ran.
.DESCRIPTION
   Builds the Windows update logs from a time specified in a file and then
   updates that file to contain the latest run time. This function is intended
   to be run to automate the collection of the Windows update logs into a SIEM
   solution such as Splunk. This function leverages the Get-WindowsUpdateLog
   cmdlet to convert .etl log files into a text-based log file. This function
   should be executed by an account with administrative rights.
.EXAMPLE
   Invoke-GetLatestWindowsUpdateLogs -etlDirectoryPath "C:\Windows\Logs\WindowsUpdate" `
    -lastRunTimeFilePath "C:\WULogScript\lastruntime.txt" `
    -LogOutputSource "C:\WULogScript\WindowsUpdate.log" `
    -eventLogSource "GetLatestWindowsUpdateLogs"
.etlDirectoryPath
   The path to the directory containing the Windows update .etl log files.
   The default location is: C:\Windows\Logs\WindowsUpdate
.lastRunTimeFilePath
   The location of the file containing a timestamp of the last time the function ran. The file
   should only contain the timestamp (generated using (Get-Date).toString()). The file will be
   overwritten as a part of the function. If the file is not present, the user executing the
   function does not have rights to the file or if the file data is invalid then a date of
   1/1/2018 will be assumed and all Windows update logs written after that date will be processed.
.logOutputPath
   The path for the text-based Windows update log to be written to. This file will be overwritten 
   the next time the function runs.
.eventLogSource
   The name of the Windows Event Log source that will be instantiated in the Windows Application 
   Event Log. This is used to log the function's actions into a log that is assumed to be 
   ingested by a SIEM solution.
#>
    Param (
        [Parameter(mandatory=$true)]
        [string]$etlDirectoryPath,
        [Parameter(mandatory=$true)]
        [string]$lastRunTimeFilePath,
        [Parameter(mandatory=$true)]
        [string]$logOutputPath,
        [Parameter(mandatory=$true)]
        [string]$eventLogSource
    )

    try {
        # Test if the Windows Application Event Log source has been instantiated yet.        
        if(-not [System.Diagnostics.EventLog]::SourceExists($eventLogSource)) {
            # Instantiate the log source.
            New-EventLog -LogName Application -Source $eventLogSource
        }
    }
    catch {
        # Depending on the rights of the using invoking the function the previous
        # test may throw an error which just indicates that the Log source is not
        # present.
        New-EventLog -LogName Application -Source $eventLogSource
    }

    try {
        # Test is if the last run time file is valid.
        if(Test-Path -Path $lastRunTimeFilePath) {
        
             try {
                # Get the content of the last run time file and convert it into a DateTime.
                $fileTimeContent = Get-Content -Path $lastRunTimeFilePath
                $lastRunTime = [DateTime]$fileTimeContent
             }
             catch {
                # If there is a problem accessing the run time file or if the data does not convert into a DateTime then set the last run time to 60 days earlier and log this.
                $lastRunTime = (Get-Date).AddDays(-60)
                Write-EventLog -LogName Application -Source $eventLogSource -EventId 11666 -Message "Unable to access $lastRunTimeFilePath or bad last run time."
             }
        }
        else {
            # If the last run time file doesn't exist set the last run time to 60 days earlier and log this.
            $lastRunTime = (Get-Date).AddDays(-60)
            Write-EventLog -LogName Application -Source $eventLogSource -EventId 11667 -Message "Last run time file $lastRunTimeFilePath does not exist."
        }

        # Get all files with modified times greater then the last run time.
        $filesToCheck = Get-ChildItem -Path $etlDirectoryPath -File | where {$_.LastWriteTime -gt $lastRunTime}

        # If there are files to check then run Get-WindowsUpdateLog against them.
        if($filesToCheck) {
            $filesToCheck | Get-WindowsUpdateLog -LogPath $logOutputPath
            $fileCheckCount = $filesToCheck.Count
        }
        else {
            $fileCheckCount = 0
        }

        # Set the current run time and update the last run time file with the updated timestamp.
        $currentRunTime = (Get-Date).ToString()
        Set-Content -Path $lastRunTimeFilePath -Value $currentRunTime -Force

        # Update the Windows Application Event Log with function run information.
        Write-EventLog -LogName Application -Source $eventLogSource -EventId 11660 -Message "GetLatestWindowsUpdateLogs ran: $fileCheckCount files. Previous run time was: $lastRunTime"

        return
    }
    catch {
        Write-EventLog -LogName Application -Source $eventLogSource -EventId 11668 -Message $_.Exception
        throw $_
    }

}

# Run the script only on systems with OS build numbers greater then $earliestBuildtoRun.
if([Environment]::OSVersion.Version.Build -ge $earliestBuildtoRun) {
    Invoke-ProcessLatestWindowsUpdateLogs -etlDirectoryPath $logPath -lastRunTimeFilePath $runTimePath -logOutputPath $outputPath -eventLogSource $eventLogSourceName
    return
}
