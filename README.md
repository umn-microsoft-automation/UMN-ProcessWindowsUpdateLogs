# UMN-ProcessWindowsUpdateLogs

This script is used to convert Windows Update logs for Server 2016 systems
into text-based logs for ingestion into a SIEM system such as Splunk. The script 
is designed to run on a regular basis so that only logs that have not been 
converted since the last script run-time are processed. The script needs to be 
run with administrative rights. This script should be set to automatically run 
either using Windows Task Scheduler or built-in functionality through the SIEM.

The script requires that the following variables be set:

* $logPath
** This is the location of the Windows Update log files (default is C:\Windows\Logs\WindowsUpdate).
* $runTimePath
** This is the location of the file that tracks the last run time of the script.
* $outputPath
** This is the path where the output file will be written to (this is overwritten with each run).
* $eventLogSourceName
** This is the Windows Event Log source name used by the script when logging to the Application event log.
* $earlierstBuildtoRun
** This is the earliest Windows build number that the script will run on. The earliest Windows 10/Server 2016 build number is 10240.
