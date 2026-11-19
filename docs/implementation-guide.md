# Implementation Guide

This guide describes the build, publish, deploy, interactive-access, and validation workflow for the Windows developer tools image.

## Prerequisites

- A Windows build host configured for Windows container builds.
- Docker Engine or another compatible Windows image builder.
- AWS CLI authenticated with permission to push to the target ECR repository.
- An ECR repository created in the target AWS Region.
- kubectl configured for the target EKS cluster.
- Permission to create or update Deployments in the `windows` namespace.
- A compatible Windows Server 2025 EKS worker node.

Keep the build host separate from the EKS worker node. The worker uses containerd to run Kubernetes containers; Docker is not required on the worker.

## 1. Review the build context

- `Dockerfile`: selects Windows Server Core LTSC 2025, copies scripts, runs installation, configures environment variables, verifies tools, and defines the container startup command.
- `install-tools.ps1`: installs Git, Java, AWS CLI, Node.js, Python, and pip.
- `install-cli-tools.ps1`: downloads kubectl and Terraform.

Build from the directory containing these files so the `COPY` instructions can find them.

## 2. Build the image

```powershell
docker build -t windows-devtools:v6 .
docker image ls windows-devtools
```

The installation scripts run during image build. Tools are baked into the image and are not reinstalled each time a pod starts.

## 3. Authenticate to Amazon ECR

Replace placeholders before running:

```powershell
$Region = "<AWS_REGION>"
$AccountId = "<AWS_ACCOUNT_ID>"
$Registry = "$AccountId.dkr.ecr.$Region.amazonaws.com"

aws sts get-caller-identity
aws ecr get-login-password --region $Region |
  docker login --username AWS --password-stdin $Registry
```

The identity needs permission to authenticate and push image layers and manifests to the target ECR repository.

## 4. Tag and push the image

```powershell
$Repository = "windows/demo"
$Tag = "devtools-v6"
$Image = "$Registry/$Repository`:$Tag"

docker tag windows-devtools:v6 $Image
docker push $Image
```

Confirm the image tag in the ECR console or by running:

```powershell
aws ecr describe-images --repository-name $Repository --region $Region
```

## 5. Configure and apply the Kubernetes manifest

Edit `kubernetes/windows-devtools-deployment.yaml` and replace the example image value with the full ECR image URI.

The node selector `kubernetes.io/os: windows` directs the scheduler to Windows nodes. The target node must also have sufficient resources and no untolerated taints.

```powershell
kubectl apply -f kubernetes/windows-devtools-deployment.yaml
kubectl rollout status deployment/windows-devtools-v6 -n windows
kubectl get pods -n windows -o wide
```

## 6. Open an interactive PowerShell session

```powershell
kubectl exec -it -n windows deployment/windows-devtools-v6 -- powershell.exe
```

This starts an additional interactive PowerShell process inside the running container. It does not require an interactive login to the EC2 worker node.

## 7. Verify installed packages

Run inside the container:

```powershell
git --version
node --version
npm --version
python --version
pip --version
java -version
aws --version
kubectl version --client
terraform version
Get-Content C:\workspace\status.txt
```

The status file indicates that the Dockerfile reached the status-file build step; the version commands separately check that the executables are available.

## 8. Troubleshooting

### Pod remains Pending

```powershell
kubectl describe pod -n windows <POD_NAME>
kubectl describe node <WINDOWS_NODE_NAME>
```

Check the Windows node selector, node taints, node readiness, and available CPU, memory, and ephemeral storage.

### ImagePullBackOff

Check the ECR image URI and tag, worker-node ECR image-pull permissions, and network access.

```powershell
kubectl describe pod -n windows <POD_NAME>
```

### Pod is Evicted

Inspect pod events and node conditions. A disk-pressure or ephemeral-storage eviction requires addressing the node storage capacity and kubelet-reported resources. Do not remove a disk-pressure taint while the condition is true.

### kubectl exec fails

Confirm the pod is Running and Ready, and that the container command is correct:

```powershell
kubectl get pods -n windows
kubectl describe pod -n windows <POD_NAME>
```

## Security and operations

- Keep credentials out of Dockerfiles, scripts, images, and Git.
- Use least-privilege IAM for ECR publishing and in-container AWS access.
- Use least-privilege Kubernetes RBAC for developers.
- Pin tool versions and validate installer checksums.
- Scan the resulting image and rebuild it regularly.
- Use persistent storage if workspace files must survive pod replacement.