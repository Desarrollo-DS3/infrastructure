# infrastructure

Kubernetes manifests and provisioning scripts for a microservice e-commerce platform,
built for the Software Engineering III course at Universidad del Valle.

[![Kubernetes](https://img.shields.io/badge/Kubernetes-k3d-326CE5.svg?logo=kubernetes&logoColor=white)](https://k3d.io/)
[![RabbitMQ](https://img.shields.io/badge/RabbitMQ-cluster--operator-FF6600.svg?logo=rabbitmq&logoColor=white)](https://www.rabbitmq.com/kubernetes/operator/operator-overview)
[![Elastic](https://img.shields.io/badge/Elastic-ECK-005571.svg?logo=elasticsearch&logoColor=white)](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html)

This is the deployment layer, not application code. It creates the cluster, pins each
service to its own node, wires messaging and logging, and brings the whole system up
with one script.

## What `setup.sh` builds

A local **k3d** cluster named `store-cluster` with one server and four agents. Services
are applied in dependency order, and each step **waits on a readiness condition** rather
than sleeping blindly.

```
                          host :8000
                              │
                    ┌─────────▼──────────┐
                    │ gateway  (FastAPI) │  NodePort 30100
                    │ agent-0            │
                    └─────────┬──────────┘
            ┌─────────────────┼─────────────────┐
     ┌──────▼──────┐   ┌──────▼──────┐   ┌──────▼───────┐
     │ auth        │   │ stock       │   │ transaction  │
     │ agent-3     │   │ agent-1     │   │ agent-2      │
     └─────────────┘   └──────┬──────┘   └──────┬───────┘
                              │                 │
                       AWS RDS MySQL     MySQL 5.6 in-cluster
                        (managed)         + PersistentVolume

     rabbit  ── RabbitmqCluster, reached by stock and transaction
     ELK     ── Elasticsearch · Kibana · Logstash · Filebeat, over every pod
```

## One node per service, on purpose

Each agent carries a label, and every Deployment declares a matching
`requiredDuringSchedulingIgnoredDuringExecution` node affinity.

| Node | Label / taint | Runs |
|---|---|---|
| `server-0` | `dedicated=server:NoSchedule` | control plane only |
| `agent-0` | `gateway=true` | gateway |
| `agent-1` | `stock=true` | stock |
| `agent-2` | `transaction=true` | transaction and its MySQL |
| `agent-3` | `auth=true` | auth |

The taint on the server keeps workloads off the control plane. The labels stop two
services from being co-scheduled by accident, which is what makes per-service resource
use and log volume readable instead of averaged across a shared node.

## Services

| Service | Type | Exposure | State |
|---|---|---|---|
| `gateway` | FastAPI | `NodePort` 30100, mapped to host `:8000` | stateless |
| `auth` | issues JWTs | `ClusterIP` | stateless |
| `stock` | Java / Spring Boot, port 9090 | `ClusterIP` | **AWS RDS** MySQL, outside the cluster |
| `transaction` | port 8080 | `ClusterIP` | `mysql:5.6` Deployment with a PersistentVolume |

Two different persistence strategies on purpose: `stock` points at a managed RDS
instance, `transaction` runs its own database in-cluster behind a volume. The gateway is
the only thing reachable from outside.

## Messaging

RabbitMQ is not a plain Deployment. `setup.sh` installs the official **RabbitMQ Cluster
Operator**, blocks until the `rabbitmqclusters.rabbitmq.com` CRD reports `Established`,
and only then declares a `RabbitmqCluster` (`rabbitmq:4.0.3-management-alpine`). Queues
and bindings are loaded at boot from a ConfigMap of definitions, so the broker comes up
already configured instead of being clicked together afterwards.

Broker credentials are never written into a manifest. The operator generates the
`rabbit-default-user` Secret, and the `stock` and `transaction` Deployments read the
username and password straight out of it.

## Observability

Logging runs on **Elastic Cloud on Kubernetes** operator CRDs, not raw Deployments.

| Manifest | Resource |
|---|---|
| `elk/elasticsearch.yaml` | `kind: Elasticsearch` |
| `elk/kibana.yaml` | `kind: Kibana` |
| `elk/logstash.yaml` | `kind: Logstash` |
| `elk/filebeat.yaml` | `kind: Beat` |

Filebeat mounts the node's container log directories and ships to Logstash. The pipeline
parses each log line as JSON, whitelists the `msg` field and renames it to `message`, so
what reaches Elasticsearch is structured rather than raw console output.

## Configuration and secrets

Every service splits its environment in two. Non-sensitive values go in a ConfigMap
(database URL, RabbitMQ host, log level); credentials go in a Secret (database user and
password, and the shared `JWT_SECRET_KEY`).

`stock` and `transaction` both read `JWT_SECRET_KEY` from the same `auth-secrets`
Secret. That is what lets a token minted by `auth` be validated downstream without a
round trip back to it.

## Running it

Requires `k3d` and `kubectl` on the PATH.

```bash
./setup.sh      # create the cluster and deploy the full stack
./test.sh       # benchmark the broker
./destroy.sh    # remove deployments and services, then delete the cluster
```

The gateway answers on `http://localhost:8000`.

`test.sh` pulls the operator-generated credentials out of the cluster, runs
`pivotalrabbitmq/perf-test` as a pod against the broker and follows its logs.

## Scope

Course project, not a product. Service images are pulled from Docker Hub as built by the
team, so the cluster is reproducible only alongside those images. The Elastic Agent block
at the end of `setup.sh` enrolls against a hosted Elastic Cloud deployment and needs your
own endpoint and API key to work.

## Related repositories

| Repository | What it is |
|---|---|
| [`stock-service`](https://github.com/Desarrollo-DS3/stock-service) | Catalog and inventory service, Java and Spring Boot, hexagonal architecture |
| [`gateway-service`](https://github.com/Desarrollo-DS3/gateway-service) | Gateway CI pipeline, FastAPI with pytest |
| [`ecommerce-frontend`](https://github.com/Desarrollo-DS3/ecommerce-frontend) | Web client |
