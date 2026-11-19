# Version Matrix

This matrix records the versions verified in the Windows Developer Tools v6 project notes. It is a record of the tested image, not a guarantee that upstream download endpoints will always produce identical artifacts.

## v6 toolchain

| Component | Version / reference | Notes |
|---|---|---|
| Windows base image | `mcr.microsoft.com/windows/servercore:ltsc2025` | Windows Server Core LTSC 2025 |
| Windows EKS worker | Windows Server 2025 | Target worker OS reported for this project |
| Docker Engine | 29.9.3 | Build host version recorded in project notes |
| Git for Windows | 2.56.0.windows.1 | Installer URL specifies this version |
| OpenJDK | 17.0.21 | Extracted from Adoptium Java 17 archive |
| AWS CLI | 2.41.0 | Verified in v6; script uses the AWS CLI MSI endpoint without an explicit version in the URL |
| Node.js | 24.22.3 | Installer URL specifies this version |
| npm | 11.19.1 | Installed with Node.js |
| Python | 3.14.9 | Installer URL specifies this version |
| pip | 26.2.2 | Installed with Python |
| kubectl | 1.37.2 | Download URL specifies this version |
| Terraform | 1.17.2 | Download URL specifies this version |
| Kubernetes node runtime | containerd | Runtime reported on the EKS Windows worker |

## Version pinning notes

The v6 script uses exact version URLs for Git, Node.js, Python, kubectl, and Terraform. Two sources are not fully pinned by the current scripts:

- **Java:** `install-tools.ps1` uses the Adoptium `latest/17` endpoint. The observed v6 Java version was 17.0.21, but a later rebuild may receive a newer Java 17 update.
- **AWS CLI:** `install-tools.ps1` downloads `https://awscli.amazonaws.com/AWSCLIV2.msi`, which does not encode a version in the URL. The observed v6 version was 2.41.0, but a later rebuild may receive a newer release.

For a reproducible rebuild, pin the Java and AWS CLI artifacts too, record their checksums, and update this matrix whenever the tested image changes.

## Validation commands

Run inside the Windows developer container:

```powershell
git --version
java -version
aws --version
node --version
npm --version
python --version
pip --version
kubectl version --client
terraform version
```

Record the image tag, build date, and command output when publishing a new version.

## Updating this matrix

When changing a package:

1. Update the installer URL or package source in the relevant PowerShell script.
2. Build a new image tag rather than overwriting an existing release tag.
3. Run all validation commands inside the final image.
4. Update the version in this table and the README.
5. Record any compatibility changes for the Windows base image and EKS worker.