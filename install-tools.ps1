$ErrorActionPreference = 'Stop' 
$ProgressPreference = 'SilentlyContinue' 
$downloads = 'C:\tools\downloads' 
New-Item -ItemType Directory -Force -Path $downloads | Out-Null 
Write-Output "=== Downloading developer tools ===" 
# 1. Download Git 
Invoke-WebRequest -UseBasicParsing ` 

    'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.1/Git-2.56.0-64-bit.exe' ` 

    -OutFile "$downloads\git.exe" 

# 2. Download Java 17 

Invoke-WebRequest -UseBasicParsing ` 

    'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse' ` 

    -OutFile "$downloads\java17.zip" 

 # 3. Download AWS CLI 

Invoke-WebRequest -UseBasicParsing ` 

    'https://awscli.amazonaws.com/AWSCLIV2.msi' ` 

    -OutFile "$downloads\awscliv2.msi" 

 # 4. Download Node.js 24 

Invoke-WebRequest -UseBasicParsing ` 

    'https://nodejs.org/dist/v24.22.3/node-v24.22.3-x64.msi' ` 

    -OutFile "$downloads\nodejs.msi" 

 # 5. Download Python 3.14 

Invoke-WebRequest -UseBasicParsing ` 

    'https://www.python.org/ftp/python/3.14.9/python-3.14.9-amd64.exe' ` 

    -OutFile "$downloads\python.exe" 

 Write-Output "=== Installing Git ===" 

 $git = Start-Process "$downloads\git.exe" ` 

    -ArgumentList '/VERYSILENT','/NORESTART','/NOCANCEL','/SP-' ` 

    -Wait -PassThru 

 if ($git.ExitCode -ne 0) { 

    throw "Git installation failed: $($git.ExitCode)" 

} 

Write-Output "=== Installing Java 17 ===" 

New-Item -ItemType Directory -Force -Path C:\Java | Out-Null 

Expand-Archive ` 

    -Path "$downloads\java17.zip" ` 

    -DestinationPath C:\Java ` 

    -Force 

$jdk = Get-ChildItem C:\Java -Directory | 

    Where-Object { $_.Name -like 'jdk-17*' } | 

    Select-Object -First 1 

if (-not $jdk) { 

    throw 'Java 17 extraction failed' 

} 

if (Test-Path C:\Java\jdk-17) { 

    Remove-Item C:\Java\jdk-17 -Recurse -Force 

} 

Rename-Item $jdk.FullName 'jdk-17' 

Write-Output "=== Installing AWS CLI ===" 

$aws = Start-Process msiexec.exe ` 

    -ArgumentList '/i',"$downloads\awscliv2.msi",'/qn','/norestart' ` 

    -Wait -PassThru 

 
if ($aws.ExitCode -notin @(0,3010)) { 

    throw "AWS CLI installation failed: $($aws.ExitCode)" 

} 

Write-Output "=== Installing Node.js and npm ===" 

$node = Start-Process msiexec.exe ` 

    -ArgumentList '/i',"$downloads\nodejs.msi",'/qn','/norestart' ` 

    -Wait -PassThru 

if ($node.ExitCode -notin @(0,3010)) { 

    throw "Node.js installation failed: $($node.ExitCode)" 

} 

Write-Output "=== Installing Python 3.14 and pip ===" 

$python = Start-Process "$downloads\python.exe" ` 

    -ArgumentList '/quiet','InstallAllUsers=1','TargetDir=C:\Python314','Include_pip=1','Include_test=0','PrependPath=0','Include_launcher=0','/log','C:\tools\python-install.log' ` 

    -Wait -PassThru 

Write-Output "Python installer exit code: $($python.ExitCode)" 

if ($python.ExitCode -notin @(0,3010)) { 

    if (Test-Path C:\tools\python-install.log) { 

        Get-Content C:\tools\python-install.log -Tail 40 

    } 

    throw "Python installation failed: $($python.ExitCode)" 

} 

# Verify Python installation 

$pythonExe = 'C:\Python314\python.exe' 

$pipExe = 'C:\Python314\Scripts\pip.exe' 

if (-not (Test-Path $pythonExe)) { 

    if (Test-Path C:\tools\python-install.log) { 

        Get-Content C:\tools\python-install.log -Tail 40 

    } 

    throw "Python executable missing: $pythonExe" 

} 

if (-not (Test-Path $pipExe)) { 

    throw "pip executable missing: $pipExe" 

} 

Write-Output "=== Configuring environment ===" 

$env:JAVA_HOME = 'C:\Java\jdk-17' 

$env:PATH = @( 

    'C:\tools' 

    'C:\Java\jdk-17\bin' 

    'C:\Program Files\Git\cmd' 

    'C:\Program Files\Amazon\AWSCLIV2' 

    'C:\Program Files\nodejs' 

    'C:\Python314' 

    'C:\Python314\Scripts' 

    'C:\Windows\System32' 

    'C:\Windows' 

    'C:\Windows\System32\Wbem' 

    'C:\Windows\System32\WindowsPowerShell\v1.0' 

) -join ';' 

Write-Output "=== Verifying all installations ===" 

git --version 

java -version 

aws --version 

node.exe --version 

npm.cmd --version 

& $pythonExe --version 

& $pipExe --version 

Write-Output "=== All developer tools installed successfully ===" 

Remove-Item -Recurse -Force $downloads 
