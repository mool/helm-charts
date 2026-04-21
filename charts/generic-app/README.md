# generic-app

![Version: 0.3.2](https://img.shields.io/badge/Version-0.3.2-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

A generic Helm chart for deploying applications in Kubernetes. This chart
provides a flexible, security-hardened foundation for deploying both
stateless and stateful workloads with sensible defaults and extensive
customization options.

**Homepage:** <https://github.com/mool/helm-charts>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Pablo Gutiérrez del Castillo | <pablo@pgc.ar> | <https://pgc.ar> |

## Source Code

* <https://github.com/mool/helm-charts>

## Features

- **Flexible Workload Types**: Deploy as Deployment or StatefulSet
- **Security-Hardened Defaults**: Non-root user, read-only filesystem, dropped capabilities, seccomp profiles
- **ConfigMap Support**: Create and auto-mount configuration files
- **Ingress Configuration**: Expose services with customizable ingress rules
- **Horizontal Pod Autoscaling**: Scale based on CPU/memory utilization
- **ServiceMonitor**: Prometheus monitoring integration out of the box
- **NetworkPolicy**: Control pod network traffic for enhanced security
- **PodDisruptionBudget**: Ensure high availability during disruptions
- **Headless Service**: Support for StatefulSet DNS resolution
- **Extra Manifests**: Render arbitrary additional Kubernetes resources from values

## Prerequisites

- Kubernetes 1.19+
- Helm 3.x

## Installation

### Install from OCI Registry

```bash
helm install my-app oci://ghcr.io/mool/generic-app
```

### Install with Custom Values

```bash
helm install my-app oci://ghcr.io/mool/generic-app -f values.yaml
```

### Install with Inline Values

```bash
helm install my-app oci://ghcr.io/mool/generic-app \
  --set image.repository=my-image \
  --set image.tag=v1.0.0
```

## Examples

### Basic Web Application

Deploy a simple web application:

```yaml
# values-webapp.yaml
appName: my-webapp

image:
  repository: nginx
  tag: "1.25"

replicaCount: 2

service:
  type: ClusterIP
  port: 80

containerPort: 80

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
```

```bash
helm install webapp oci://ghcr.io/mool/generic-app -f values-webapp.yaml
```

### StatefulSet with Persistent Storage

Deploy a stateful application (e.g., database) with persistent volumes:

```yaml
# values-stateful.yaml
appName: my-database

workloadType: StatefulSet

image:
  repository: postgres
  tag: "16"

replicaCount: 3

containerPort: 5432

service:
  type: ClusterIP
  port: 5432
  headless:
    enabled: true

statefulSet:
  podManagementPolicy: OrderedReady
  updateStrategy:
    type: RollingUpdate
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: "standard"
        resources:
          requests:
            storage: 10Gi

volumeMounts:
  - name: data
    mountPath: /var/lib/postgresql/data

# Adjust security context for postgres
podSecurityContext:
  runAsUser: 999
  runAsGroup: 999
  fsGroup: 999
  runAsNonRoot: true

securityContext:
  runAsUser: 999
  runAsGroup: 999
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false  # Postgres needs write access

resources:
  limits:
    cpu: "1"
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

```bash
helm install database oci://ghcr.io/mool/generic-app -f values-stateful.yaml
```

### Extra Manifests

Render additional resources that are not modeled directly by the chart:

```yaml
# values-extra-manifests.yaml
extraManifests:
  - apiVersion: v1
    kind: Secret
    metadata:
      name: '{{ include "app.name" . }}-credentials'
    type: Opaque
    stringData:
      username: admin
      password: '{{ .Release.Name }}-password'
  - apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: '{{ include "app.name" . }}'
    spec:
      refreshInterval: 1h
      secretStoreRef:
        kind: ClusterSecretStore
        name: vault
      target:
        name: '{{ include "app.name" . }}-credentials'
      data:
        - secretKey: password
          remoteRef:
            key: apps/{{ .Release.Name }}/password
```

```bash
helm install my-app oci://ghcr.io/mool/generic-app -f values-extra-manifests.yaml
```

## Security Defaults

This chart is designed with security-first defaults:

- **Non-root execution**: Containers run as user/group `10001` by default
- **Read-only root filesystem**: Prevents runtime modifications to the container filesystem
- **Dropped capabilities**: All Linux capabilities are dropped by default
- **No privilege escalation**: `allowPrivilegeEscalation` is set to `false`
- **Seccomp profile**: Uses `RuntimeDefault` seccomp profile
- **Resource limits**: Default CPU, memory, and ephemeral storage limits are set
- **Service account**: Auto-mounting of service account tokens is disabled by default

To customize security settings, override the `podSecurityContext` and `securityContext` values as needed.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| appName | string | `""` | App name. |
| autoscaling | object | `{"enabled":false,"maxReplicas":10,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/ |
| configMap | object | `{"data":{},"enabled":false,"mountPath":"","volumeName":"config"}` | ConfigMap configuration - creates a ConfigMap with specified data |
| containerPort | int | `8080` | Container port configuration |
| extraManifests | list | `[]` | Additional arbitrary manifests to render alongside the chart resources. Each item may be a Kubernetes object map or a raw YAML string, and is rendered through tpl so you can reference .Values, .Release, and named templates. Example: extraManifests:   - apiVersion: v1     kind: Secret     metadata:       name: "{{ include \"app.name\" . }}-extra"     type: Opaque     stringData:       token: "{{ .Release.Name }}" |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.repository | string | `"nginx"` | The image repository name. |
| image.tag | string | `""` | The image tag. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ingress | object | `{"annotations":{},"className":"","enabled":false,"hosts":[],"tls":[]}` | This block is for setting up the ingress for more information can be found here: https://kubernetes.io/docs/concepts/services-networking/ingress/ |
| livenessProbe | object | `{}` | This is to setup the liveness probe more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| networkPolicy.egress | list | `[{"ports":[{"port":53,"protocol":"UDP"}],"to":[]},{"ports":[{"port":443,"protocol":"TCP"}],"to":[]}]` | Egress rules |
| networkPolicy.enabled | bool | `false` | Enable NetworkPolicy creation |
| networkPolicy.ingress | list | `[{"from":[{"podSelector":{"matchLabels":{"app.kubernetes.io/name":"ingress-controller"}}}],"ports":[{"port":8080,"protocol":"TCP"}]}]` | Ingress rules |
| networkPolicy.policyTypes | list | `["Ingress","Egress"]` | Policy types to enforce |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podDisruptionBudget.enabled | bool | `false` | Enable PodDisruptionBudget creation |
| podDisruptionBudget.maxUnavailable | string | `nil` | Maximum number of pods that can be unavailable during voluntary disruptions. Set either maxUnavailable or minAvailable, but not both. Examples:   maxUnavailable: 1        # allow 1 pod to be unavailable   maxUnavailable: "25%"    # allow 25% of pods to be unavailable |
| podDisruptionBudget.minAvailable | string | `nil` | Minimum number of pods that must remain available during voluntary disruptions. Set either maxUnavailable or minAvailable, but not both. Examples:   minAvailable: 1          # at least 1 pod must be available   minAvailable: "50%"      # at least 50% of pods must be available |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| readinessProbe | object | `{}` | This is to setup the readiness probe. |
| replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| service.headless.enabled | bool | `false` | Creates an additional headless service (clusterIP: None) for stable network identity |
| service.port | int | `80` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| service.type | string | `"ClusterIP"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `false` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| serviceMonitor | object | `{"annotations":{},"enabled":false,"endpoints":[],"interval":"30s","labels":{},"path":"/metrics","portName":"http","scrapeTimeout":"10s"}` | ServiceMonitor configuration for Prometheus monitoring |
| startupProbe | object | `{}` | This is to setup the startup probe. |
| statefulSet.podManagementPolicy | string | `"OrderedReady"` | Pod management policy: OrderedReady or Parallel OrderedReady: Pods are created/terminated in order (default StatefulSet behavior) Parallel: Pods are created/terminated in parallel |
| statefulSet.serviceName | string | `""` | Service name for the StatefulSet (defaults to headless service name or app name) This must match a headless service for proper DNS resolution |
| statefulSet.updateStrategy | object | `{"type":"RollingUpdate"}` | Update strategy for StatefulSet |
| statefulSet.volumeClaimTemplates | list | `[]` | Volume claim templates for persistent storage Each pod in the StatefulSet will get its own PVC |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |
| workloadType | string | `"Deployment"` | Workload type: "Deployment" or "StatefulSet" For more information see: - Deployments: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/ - StatefulSets: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/ |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
