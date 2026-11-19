# escape=` 
FROM mcr.microsoft.com/windows/servercore:ltsc2025 
SHELL ["powershell.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"] 
# Create working directories 
RUN New-Item -ItemType Directory -Force -Path C:\workspace, C:\tools 
WORKDIR C:/workspace 
# Install Git, Java, AWS CLI, Node.js, Python and pip 
COPY install-tools.ps1 C:/tools/install-tools.ps1 
RUN powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:/tools/install-tools.ps1 
# Install kubectl and Terraform 
COPY install-cli-tools.ps1 C:/tools/install-cli-tools.ps1 
RUN powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:/tools/install-cli-tools.ps1 
# Configure developer tool paths 
ENV PATH="C:\tools;C:\Java\jdk-17\bin;C:\Program Files\Git\cmd;C:\Program Files\Amazon\AWSCLIV2;C:\Python314;C:\Python314\Scripts;C:\Program Files\nodejs;C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0" 
ENV JAVA_HOME="C:\Java\jdk-17" 
# Verify Python and Node.js in final image 
RUN powershell.exe -NoProfile -Command "git --version; node --version; npm.cmd --version; python.exe --version; pip.exe --version; java -version; aws --version; kubectl version --client; terraform version" 
# Create workspace status file 
RUN Set-Content -Path C:/workspace/status.txt -Value 'Windows Developer Container Build Successful' 
# Keep container running for interactive access 
CMD ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", "-NoLogo", "-NoProfile", "-Command", "while ($true) { Start-Sleep -Seconds 3600 }"] 
