# Kubernetes Challenge — Fundamentals in Practice

Deploy a REST API (PostgREST) backed by a PostgreSQL database on a local Kubernetes cluster, and prove that the data survives when the database Pod is destroyed.

Everything is declared in versioned YAML manifests: namespace, persistent storage, ConfigMap/Secret, health checks, resource limits and autoscaling (HPA).

## Architecture

```mermaid
flowchart LR
    subgraph CL["Cluster (docker-desktop)"]
        subgraph NS["Namespace kubernetes-challenge"]
            SA["API Service"] --> A1["PostgREST Pod"]
            SA --> A2["PostgREST Pod"]
            HPA["HPA"] -.->|"scales replicas"| DA["PostgREST Deployment"]
            DA -.-> A1
            DA -.-> A2
            A1 --> SP["Postgres Service (ClusterIP)"]
            A2 --> SP
            SP --> P["PostgreSQL Pod"]
            DP["PostgreSQL Deployment (1 replica)"] -.-> P
            P --> PVC["PVC"]
            CM["ConfigMap"] -.-> DA
            CM -.-> DP
            SEC["Secret"] -.-> DA
            SEC -.-> DP
        end
        subgraph KS["Namespace kube-system"]
            MS["metrics-server"]
        end
        subgraph CS["Cluster-scoped resources"]
            PV["PersistentVolume"]
            SC["StorageClass (hostpath)"]
        end
    end
    U["You (curl)"] -->|"port-forward"| SA
    PVC -->|"bound to"| PV
    SC -.->|"provisions"| PV
    MS -.->|"CPU metrics"| HPA
```

Solid arrows are traffic or data; dashed arrows mean "manages", "configures" or "feeds".

The diagram has three layers:

- **Outside the cluster:** you, calling the API with `curl`.
- **Cluster-scoped resources:** the StorageClass and the PersistentVolume belong to no namespace. The PVC is the *request* for storage and lives in the namespace. The PV is the actual volume. The StorageClass is what created that PV on demand.
- **Namespaced resources:** everything the challenge deploys, isolated in `kubernetes-challenge`. The exception is metrics-server, which lives in `kube-system`.

ConfigMap and Secret point to the **Deployments** because the injection is declared in the Pod template, so every replica receives it.

The API reaches the database by the **name of the Postgres Service** (cluster DNS), never by Pod IP. Pods can be recreated and change IP; the Service name stays the same.

## Stack

| Component | Role |
|---|---|
| **Docker Desktop** (built-in Kubernetes) | Local single-node cluster, zero cost |
| **kubectl** | CLI that talks to the cluster API |
| **PostgreSQL** | Relational database, the *stateful* part |
| **PostgREST** | Generates a REST API from the Postgres schema, the *stateless* part |
| **metrics-server** | CPU/memory metrics for the HPA |
| **GitHub Actions** | CI: secret leak scan, credential checks and manifest validation |

### Kubernetes as a restaurant

- **Cluster / control plane**: management decides; the **node** is the kitchen that executes.
- **Namespace**: a reserved area of the dining room just for your event.
- **Pod**: a cook at work.
- **Deployment**: the manager who guarantees X cooks per shift; if one leaves, another is called in.
- **Service**: the kitchen's fixed phone extension. The waiter dials the extension, no matter which cook is on duty.
- **PVC**: the locked pantry. The ingredients stay there even when the cook goes home.
- **ConfigMap**: the menu on the wall, readable by anyone.
- **Secret**: the safe's combination written in another alphabet (Base64). It is not a real safe.
- **Probes**: the manager asking "are you alive?" and "are you ready to serve?".
- **HPA**: calling in extra cooks when the queue grows and sending them home when it empties.

## Levels

Each level was developed in its own branch and merged through a pull request.

- [x] **Level 0 — Prerequisites:** local cluster responding, node `Ready`
- [x] **Level 1 — Namespace and first Pod:** prove that a bare Pod does not come back by itself
- [ ] **Level 2 — PostgreSQL with persistence:** Deployment + PVC + ClusterIP Service
- [ ] **Level 3 — ConfigMap and Secret:** configuration and credentials out of the Deployment manifest
- [ ] **Level 4 — PostgREST + PostgreSQL:** API connected to the database by Service name
- [ ] **Level 5 — External access and persistence proof:** POST → delete DB Pod → same data on GET
- [ ] **Level 6 — Health checks, resources and scaling:** probes, requests/limits, multiple API replicas
- [ ] **Level 7 — HPA (bonus):** replicas scaling up and down with CPU load

**Out of scope, on purpose:** Ingress, StatefulSet, Helm, cloud clusters, CD, TLS, database backups and JWT auth in PostgREST.

---

## Level 0 — Prerequisites

**Cluster tool:** Docker Desktop, with Kubernetes enabled in *Settings → Kubernetes → Enable Kubernetes*.

```bash
kubectl config current-context   # docker-desktop
kubectl get nodes                # STATUS must be Ready
```

![Cluster ready](docs/evidence/level-0/cluster-ready.png)

## Level 1 — Namespace and first Pod

Every resource of the challenge lives in its own namespace, [`k8s/00-namespace.yaml`](k8s/00-namespace.yaml). A bare Pod ([`k8s/extras/test-pod.yaml`](k8s/extras/test-pod.yaml)) was created, inspected and deleted.

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/extras/test-pod.yaml
kubectl get pods -n kubernetes-challenge -o wide
kubectl describe pod test-pod -n kubernetes-challenge
kubectl logs test-pod -n kubernetes-challenge
kubectl delete pod test-pod -n kubernetes-challenge
```

```text
$ kubectl delete pod test-pod -n kubernetes-challenge
pod "test-pod" deleted from kubernetes-challenge namespace

$ kubectl get pods -n kubernetes-challenge
No resources found in kubernetes-challenge namespace.
```

Full outputs: [get](docs/evidence/level-1/01-get.txt) · [describe](docs/evidence/level-1/02-describe.txt) · [logs](docs/evidence/level-1/03-logs.txt) · [delete](docs/evidence/level-1/04-delete.txt)

**Does the deleted Pod come back by itself?** No. The Pod has no `ownerReferences`: no ReplicaSet is watching it, so nobody notices it is gone. That's why Pods are rarely created directly. A Deployment creates a ReplicaSet, which keeps comparing "desired" with "actual" and recreates missing Pods. Level 5 relies on exactly that.

> `k8s/extras/` is not applied by `kubectl apply -f k8s/`, because that command is not recursive. The test Pod is a one-off exercise, not part of the stack.
