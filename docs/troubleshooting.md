# Troubleshooting Notes

This document records troubleshooting scenarios encountered while building and running the Windows Developer Tools v6 image on Amazon EKS. Commands use placeholders where environment-specific values should be supplied.

## 1. Pod remains Pending: selector mismatch and untolerated taint

### Observed event

```text
0/2 nodes are available:
1 node(s) didn't match Pod's node affinity/selector,
1 node(s) had untolerated taint(s).
```

### What it means

- The Deployment uses `nodeSelector: kubernetes.io/os: windows`, so Linux nodes are intentionally excluded.
- The Windows worker had a `node.kubernetes.io/disk-pressure:NoSchedule` taint, which prevented scheduling.
- The selector mismatch on the Linux node was expected for this Windows-only pod; the untolerated taint on the Windows worker was the blocker to investigate.

### Checks

Run from the machine where kubectl is configured:

```powershell
kubectl get nodes
kubectl describe node <WINDOWS_NODE_NAME>
kubectl get node <WINDOWS_NODE_NAME> -o jsonpath="{.spec.taints}"
kubectl get node <WINDOWS_NODE_NAME> -o jsonpath="{range .status.conditions[?(@.type=='DiskPressure')]}{.type}={.status}{': '}{.message}{'\n'}{end}"
```

Review node Conditions, Taints, Allocatable resources, and recent Events.

### Safe remediation sequence

1. Confirm the actual Windows worker and inspect its disk usage. Do not confuse the Windows build/admin EC2 host with the EKS worker.
2. In the recorded scenario, the worker's EBS volume was increased to 150 GB. The Windows C: partition was then extended to approximately 149.5 GB, leaving approximately 106.6 GB free at the time of the check.
3. Confirm that Windows reports the new partition size and free space on the worker.
4. Re-check the Kubernetes node condition. Wait for `DiskPressure=False` and for kubelet to clear the disk-pressure taint.
5. Only if `DiskPressure=False` but the taint remains stale, consider removing that specific taint. Never remove it while the condition is `True`.

Example command, only after confirming `DiskPressure=False`:

```powershell
kubectl taint nodes <WINDOWS_NODE_NAME> node.kubernetes.io/disk-pressure:NoSchedule-
```

Re-check:

```powershell
kubectl describe node <WINDOWS_NODE_NAME>
kubectl get pods -n windows -o wide
```

## 2. Pod is Evicted because of ephemeral-storage pressure

### Observed symptoms

The v6 pod was evicted with a message indicating that the node was low on ephemeral storage. The node also reported disk pressure and image garbage collection could not reclaim enough space.

### Investigation

```powershell
kubectl describe pod <POD_NAME> -n windows
kubectl describe node <WINDOWS_NODE_NAME>
kubectl get events -n windows --sort-by=.lastTimestamp
```

On the Windows EKS worker, check the actual Windows volume:

```powershell
Get-Volume -DriveLetter C
Get-Partition -DriveLetter C
Get-Disk
```

### Guidance

- Treat `DiskPressure` as a node health issue, not merely a pod issue.
- Check kubelet-reported ephemeral-storage capacity and node conditions after changing the EBS volume.
- Do not manually delete containerd snapshots or runtime metadata to free space unless you are following a supported, carefully validated containerd cleanup procedure.
- Do not add arbitrary ephemeral-storage limits as a workaround without understanding the worker's filesystem and kubelet accounting.
- After the node recovers, verify the Deployment and pod again.

## 3. ECR image pull is slow or fails

The v6 image was successfully pulled from ECR in the recorded test. The pull took about 5 minutes 18 seconds and the image size reported by Kubernetes was approximately 3.03 GB.

Check the pod events:

```powershell
kubectl describe pod <POD_NAME> -n windows
```

Check the following:

- The image URI, repository name, and tag are correct.
- The Windows worker has the required ECR image-pull permissions.
- The worker has network access to ECR and its image layers.
- The image is compatible with the Windows worker OS/build.

Do not put AWS access keys in the Dockerfile or image. Configure the worker/pod identity and permissions outside the image.

## 4. Container is Running but interactive access fails

Check the pod and container status:

```powershell
kubectl get pods -n windows -o wide
kubectl describe pod <POD_NAME> -n windows
```

Open a PowerShell session:

```powershell
kubectl exec -it -n windows <POD_NAME> -- powershell.exe
```

The container's PowerShell sleep loop keeps the main process alive. `kubectl exec` starts an additional interactive process inside the running container; it does not require an RDP or SSH login to the worker EC2 instance.

## 5. Port-forwarding a test HTTP server

A Python HTTP server was started in the container and returned HTTP 200 when queried from inside the pod. To test port-forwarding from the build/admin host:

Inside the container, keep the server running:

```powershell
python -m http.server 8080 --bind 0.0.0.0
```

On the machine that has kubectl configured, keep this command running in a separate PowerShell window:

```powershell
kubectl port-forward -n windows pod/<POD_NAME> 8080:8080
```

From another terminal on that same machine:

```powershell
Invoke-WebRequest http://127.0.0.1:8080 -UseBasicParsing
```

The browser must be opened on the machine running `kubectl port-forward`, unless you deliberately expose/tunnel that local port another way. An HTTP 200 from a command executed inside the pod confirms the server works inside the pod, but by itself does not prove the host-side port-forward is working.

## 6. Distinguish the build host from the EKS worker

Use the Windows build/admin host for image build, ECR push, and kubectl operations when it has the necessary tools and credentials.

The EKS Windows worker runs the pod using the Kubernetes container runtime (containerd). Docker does not need to be installed on the worker just to run this Kubernetes workload.

Before running host-level commands, confirm which machine you are connected to:

```powershell
hostname
ipconfig
```

Do not run cleanup commands against containerd data or snapshots without confirming the target node and understanding the impact.

## 7. General diagnostic collection

```powershell
kubectl get nodes -o wide
kubectl get pods -n windows -o wide
kubectl get deployments -n windows
kubectl get events -n windows --sort-by=.lastTimestamp
kubectl describe pod <POD_NAME> -n windows
kubectl describe node <WINDOWS_NODE_NAME>
```

Remove or redact account IDs, private IPs, internal hostnames, and other sensitive environment details before posting diagnostic output publicly.