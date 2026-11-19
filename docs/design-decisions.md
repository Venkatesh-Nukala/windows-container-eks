# Design Decisions

This document explains the main design choices behind the Windows Developer Tools v6 reference implementation on Amazon EKS.

## 1. Windows Server Core LTSC 2025 as the base image

**Decision:** Use `mcr.microsoft.com/windows/servercore:ltsc2025`.

**Rationale:** The workspace is intended to provide a Windows environment and run on compatible Windows Server 2025 EKS worker nodes. Windows Server Core supplies the Windows user-space foundation needed by the selected Windows installers and tools.

**Trade-off:** Windows images are substantially larger than many Linux images, and host/image OS compatibility must be maintained. Confirm compatibility against the actual EKS Windows AMI and container runtime.

## 2. Build on a separate Windows build host

**Decision:** Build and test the Windows image on a dedicated Windows build/admin host rather than on the EKS worker.

**Rationale:** Image building, ECR publishing, and cluster administration are build/release activities. The EKS worker's responsibility is to run scheduled workloads.

**Trade-off:** The build host must have a compatible Windows container build environment, Docker (or another supported builder), AWS CLI, and kubectl. It also needs controlled access to AWS.

## 3. Use Docker for image construction and containerd on EKS for runtime

**Decision:** Use Docker Engine on the Windows build host to build and push the image; allow EKS/containerd to pull and run it on the Windows worker.

**Rationale:** A container image is the artifact exchanged between the build and runtime environments. The Kubernetes node does not need Docker installed just because Docker was used to build the image.

**Trade-off:** Build and runtime diagnostics use different tools. Use Docker commands on the build host and Kubernetes/containerd diagnostics for the EKS workload.

## 4. Amazon ECR as the image registry

**Decision:** Store the custom image in Amazon ECR.

**Rationale:** ECR provides a private registry integrated with AWS identity and EKS image-pull workflows. The image can be versioned with tags such as `devtools-v6`.

**Trade-off:** The publisher needs ECR push permissions, and the worker needs permission and network access to pull the image. Use IAM roles/identities rather than embedding credentials in the image.

## 5. Separate package installation into PowerShell scripts

**Decision:** Keep the Dockerfile focused on image orchestration and split package installation into `install-tools.ps1` and `install-cli-tools.ps1`.

**Rationale:** The first script installs general developer tools (Git, Java, AWS CLI, Node.js, Python, and pip). The second installs infrastructure/Kubernetes CLIs (kubectl and Terraform). This makes the build easier to read and the installation logic easier to maintain.

**Trade-off:** The scripts become part of the Docker build context and must be version-controlled and reviewed along with the Dockerfile.

## 6. Bake tools into the image

**Decision:** Install the tools at image-build time using Dockerfile `RUN` instructions.

**Rationale:** New pods start with the tools already installed. Developers do not need to repeat package installation each time a container starts, and the tool versions can be validated as part of image construction.

**Trade-off:** Updating a tool requires building and publishing a new image version. The resulting image is larger than a minimal runtime image.

## 7. Use a Windows node selector

**Decision:** The Kubernetes Deployment selects nodes with `kubernetes.io/os: windows`.

**Rationale:** Windows containers must be scheduled on compatible Windows nodes. Linux worker nodes are intentionally excluded from this workload.

**Trade-off:** The cluster must have ready, compatible Windows capacity. Taints, resource pressure, and Windows host/image compatibility can still prevent scheduling.

## 8. Keep the workspace pod alive for interactive access

**Decision:** Use a PowerShell sleep loop as the container's default command.

**Rationale:** The container's main process stays alive, allowing a developer to start an additional interactive PowerShell process with `kubectl exec -it` when needed.

**Trade-off:** The sleep loop is suitable for an interactive workspace demonstration, not a substitute for an application process or a managed multi-user development platform.

## 9. Use kubectl exec instead of logging in to the worker

**Decision:** Access the workspace with `kubectl exec -it`.

**Rationale:** Developers work inside the container rather than logging in to the underlying EC2 worker. This separates the developer's environment from the host operating system.

**Trade-off:** Users need Kubernetes authentication and RBAC permissions to access the pod. `kubectl exec` does not automatically grant AWS permissions inside the container.

## 10. Keep workspace persistence as a separate concern

**Decision:** The initial v6 workspace uses the container filesystem and does not claim durable project-file storage.

**Rationale:** The primary demonstration is the reusable developer toolchain and interactive access.

**Trade-off:** Files written only to the container writable layer can be lost when a pod is replaced. Persistent volumes and per-developer isolation should be designed before using this pattern for important or shared workspaces.

## Summary

The architecture deliberately separates image construction, image distribution, Kubernetes scheduling, and developer access. It provides a repeatable Windows tool environment while keeping host administration outside the developer container.