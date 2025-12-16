Set-ExecutionPolicy Unrestricted -Force -ErrorAction Stop
$ErrorActionPreference = "Stop"

function Invoke-Step {
    param (
        [ScriptBlock]$Action,
        [string]$ErrorMessage
    )

    try {
        & $Action
    }
    catch {
        throw ("$ErrorMessage`n$($_.Exception.Message)")
    }

    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        throw ("$ErrorMessage`nCommand exited with code $LASTEXITCODE")
    }
}

# Check which version of Apache Tomcat is currently installed
$tomcatInstallPath = "C:\Prog"
$installedTomcat = Get-ChildItem -Path $tomcatInstallPath -Directory -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -match "^apache-tomcat-(\d+\.\d+\.\d+)$" } |
    Sort-Object { [version]($_.Name -replace "apache-tomcat-", "") } -Descending |
    Select-Object -First 1

if ($installedTomcat) {
    $currentVersion = $installedTomcat.Name -replace "apache-tomcat-", ""
    $currentTomcatPath = $installedTomcat.FullName
    Write-Host "Detected installed Apache Tomcat version: $currentVersion"
    Write-Host "Installation path: $currentTomcatPath"
} else {
    throw "No Apache Tomcat installation found in '$tomcatInstallPath'."
}

# Stop the Apache Tomcat Service if it's installed and running
$serviceName = "Tomcat9"
$service = Get-Service -Name $serviceName -ErrorAction Stop

Invoke-Step { Stop-Service $serviceName -ErrorAction Stop } "Failed to stop service $serviceName."

# Uninstall the Apache Tomcat Service
$targetDirectory = "$currentTomcatPath\bin"
if (-not (Test-Path -Path $targetDirectory -PathType Container)) {
    throw "Target directory '$targetDirectory' not found for service removal."
}

Invoke-Step { Set-Location -Path $targetDirectory -ErrorAction Stop } "Failed to set location to '$targetDirectory'."
Invoke-Step { .\service.bat remove } "Failed to remove Tomcat service."

# Download and extract the latest version to the Prog folder
$tomcatUrl = "https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.113/bin/apache-tomcat-9.0.113-windows-x64.zip"
$zipFile = "apache-tomcat-9.0.113-windows-x64.zip"
$progressPreference = 'silentlyContinue'
Invoke-Step { Invoke-WebRequest $tomcatUrl -Outfile $tomcatInstallPath\$zipFile -ErrorAction Stop } "Failed to download Tomcat archive from $tomcatUrl."
Invoke-Step { Expand-Archive -Path $tomcatInstallPath\$zipFile -DestinationPath C:\Prog -Force } "Failed to extract Tomcat archive to C:\Prog."

# Copy the webapps folder from the old Tomcat to the new one
$oldWebappsFile = "$currentTomcatPath\webapps"
$newWebappsFile = "C:\Prog\apache-tomcat-9.0.113\"
Invoke-Step { Copy-Item -Path $oldWebappsFile -Destination $newWebappsFile -Recurse -Force -ErrorAction Stop } "Failed to copy webapps directory."

# Copy the logs folder from the old Tomcat to the new one
$oldLogsFile = "$currentTomcatPath\logs"
$newLogsFile = "C:\Prog\apache-tomcat-9.0.113\"
Invoke-Step { Copy-Item  -Path $oldLogsFile -Destination $newLogsFile -Recurse -Force -ErrorAction Stop } "Failed to copy logs directory."

# Update the CATALINA_HOME environment variable
Invoke-Step { [System.Environment]::SetEnvironmentVariable("CATALINA_HOME", "C:\Prog\apache-tomcat-9.0.113", "Machine") } "Failed to set CATALINA_HOME environment variable."
$env:CATALINA_HOME = "C:\Prog\apache-tomcat-9.0.113"

# Install the updated Apache Tomcat Service
$targetDirectory = "C:\Prog\apache-tomcat-9.0.113\bin"
if (-not (Test-Path -Path $targetDirectory -PathType Container)) {
    throw "Target directory '$targetDirectory' not found for service installation."
}

Invoke-Step { Set-Location -Path $targetDirectory -ErrorAction Stop } "Failed to set location to '$targetDirectory'."
Invoke-Step { .\service.bat install } "Failed to install Tomcat service."

$serviceName = "Tomcat9"
$serviceDescription = "Apache Tomcat 9.0.113 Server"

# Change the start type of the Apache Tomcat Service to Automatic
Invoke-Step { Set-Service $serviceName -StartupType Automatic -Description $serviceDescription -ErrorAction Stop } "Failed to configure service $serviceName."

# If IIQ is installed update the log4j.properties file
# Need to update log file before deleting old Tomcat folders
# C:\Prog\apache-tomcat-9.0.109\webapps\identityiq\WEB-INF\classes\log4j.properties
# The line to update is appender.file.fileName=<path to sailpoint.log file>
# The path to sailpoint.log is as follows
# C:/Prog/apache-tomcat-9.0.109/logs/sailpoint.log

# Remove the old Tomcat
$targetDirectory2 = $currentTomcatPath
if (-not (Test-Path -Path $targetDirectory2 -PathType Container)) {
    throw "Target directory '$targetDirectory2' not found for removal."
}

Invoke-Step { Set-Location -Path "C:\" -ErrorAction Stop } "Failed to set location to 'C:\'."
Invoke-Step { Remove-Item -Path $targetDirectory2 -Recurse -Force -ErrorAction Stop } "Failed to remove old Tomcat directory at '$targetDirectory2'."

# Remove the install zip file
Invoke-Step { Remove-Item -Path $tomcatInstallPath\"apache-tomcat-9.0.113-windows-x64.zip" -Recurse -Force -ErrorAction Stop } "Failed to delete Tomcat archive."

# Start the Apache Tomcat Service
Invoke-Step { Start-Service $serviceName -ErrorAction Stop } "Failed to start service $serviceName."
