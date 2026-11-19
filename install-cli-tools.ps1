PS C:\windows-devtools> cat .\install-cli-tools.ps1 
$ErrorActionPreference = 'Stop' 
$ProgressPreference = 'SilentlyContinue' 
$downloads = 'C:\tools\downloads' 
New-Item -ItemType Directory -Force -Path $downloads | Out-Null 

# Download kubectl 
Invoke-WebRequest -UseBasicParsing ` 

  'https://dl.k8s.io/v1.37.2/bin/windows/amd64/kubectl.exe' ` 

  -OutFile 'C:\tools\kubectl.exe' 

# Download Terraform 
Invoke-WebRequest -UseBasicParsing ` 

  'https://releases.hashicorp.com/terraform/1.17.2/terraform_1.17.2_windows_amd64.zip' ` 

  -OutFile "$downloads\terraform.zip" 

# Extract Terraform 
Expand-Archive -Path "$downloads\terraform.zip" -DestinationPath C:\tools -Force 

# Verify 

C:\tools\kubectl.exe version --client 

C:\tools\terraform.exe version 

Remove-Item -Recurse -Force $downloads 

PS C:\windows-devtools> 
