Set-ExecutionPolicy Unrestricted -Force
$ErrorActionPreference = "Stop"

# Stop the Apache Tomcat Service if it's installed and running
$serviceName = "Tomcat9"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if($service -ne $null) {
    Stop-Service $serviceName -ErrorAction SilentlyContinue
    } else { exit 0
}


# Uninstall the Apache Tomcat Service
$targetDirectory = "C:\Prog\apache-tomcat-9.0.43\bin"
if (Test-Path -Path $targetDirectory -PathType Container) {
    Set-Location -Path $targetDirectory
    .\service.bat remove
} else {
    exit 0
}


# up to this point everything is working as expected


# Download and extract the latest version to the Prog folder
$tomcatUrl = "https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.109/bin/apache-tomcat-9.0.109-windows-x64.zip"
$zipFile = "apache-tomcat-9.0.109-windows-x64.zip"
$progressPreference = 'silentlyContinue'
Invoke-WebRequest $tomcatUrl -Outfile $env:USERPROFILE\Desktop\$zipFile
Expand-Archive -Path $env:USERPROFILE\Desktop\$zipFile -DestinationPath C:\Prog

# Copy the webapps folder from the old Tomcat to the new one
$oldWebappsFile = "C:\Prog\apache-tomcat-9.0.43\webapps"
$newWebappsFile = "C:\Prog\apache-tomcat-9.0.109\"
Copy-Item -Path $oldWebappsFile -Destination $newWebappsFile -Recurse -Force

# Copy the logs folder from the old Tomcat to the new one
$oldLogsFile = "C:\Prog\apache-tomcat-9.0.43\logs"
$newLogsFile = "C:\Prog\apache-tomcat-9.0.109\"
Copy-Item  -Path $oldLogsFile -Destination $newLogsFile -Recurse -Force

# Update the environment variable for CATALINA_HOME
# this isn't working because the current PowerShell session isn't refreshing the variables so,
# subsequent steps don't work as expected but if you close,
# PowerShell and open a new admin session it'll have updated
[System.Environment]::SetEnvironmentVariable("CATALINA_HOME", "C:\Prog\apache-tomcat-9.0.109", "Machine")
# This didn't work >>> (Get-Item .).Refresh()


# Install the updated Apache Tomcat Service
$targetDirectory = "C:\Prog\apache-tomcat-9.0.43\bin"
if (Test-Path -Path $targetDirectory -PathType Container) {
    Set-Location -Path $targetDirectory
    .\service.bat install
} else {
    exit 0
}

$serviceName = "Tomcat9"
$serviceDescription = "Apache Tomcat 9.0.109 Server"

# Change the start type of the Apache Tomcat Service to Automatic
Set-Service $serviceName -StartupType Automatic -Description $serviceDescription

# If IIQ is installed update the log4j.properties file
# Need to update log file before deleting old Tomcat folders
# C:\Prog\apache-tomcat-9.0.109\webapps\identityiq\WEB-INF\classes\log4j.properties
# The line to update is appender.file.fileName=<path to sailpoint.log file>
# The path to sailpoint.log is as follows
# C:/Prog/apache-tomcat-9.0.109/logs/sailpoint.log

# Remove the old Tomcat
$targetDirectory2 = "C:\Prog\apache-tomcat-9.0.43"
if (Test-Path -Path $targetDirectory -PathType Container) {
    Set-Location -Path "C:\"
    Remove-Item -Path $targetDirectory2 -Recurse -Force
} else {
    exit 0
}

# Remove the install zip file
Remove-Item -Path $env:USERPROFILE\Desktop\"apache-tomcat-9.0.109-windows-x64.zip" -Recurse -Force

# Start the Apache Tomcat Service
Start-Service $serviceName -ErrorAction SilentlyContinue
