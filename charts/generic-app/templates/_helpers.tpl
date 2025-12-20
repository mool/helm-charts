{{/*
Define the name of the application.
*/}}
{{- define "app.name" -}}
{{- default .Release.Name .Values.appName | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Define the version of the application.
*/}}
{{- define "app.version" -}}
  {{- $version := default .Values.appVersion .Values.image.tag -}}
  {{- regexReplaceAll "[^a-zA-Z0-9_\\.\\-]" $version "-" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "app.labels" -}}
helm.sh/chart: {{ include "app.chart" . }}
{{ include "app.selectorLabels" . }}
app.kubernetes.io/version: {{ include "app.version" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "app.name" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Validate workloadType value
*/}}
{{- define "app.validateWorkloadType" -}}
{{- $validTypes := list "Deployment" "StatefulSet" -}}
{{- if not (has .Values.workloadType $validTypes) -}}
{{- fail (printf "Invalid workloadType: %s. Must be one of: %s" .Values.workloadType (join ", " $validTypes)) -}}
{{- end -}}
{{- end }}

{{/*
Get the headless service name
*/}}
{{- define "app.headlessServiceName" -}}
{{- printf "%s-headless" (include "app.name" .) -}}
{{- end }}

{{/*
Get the StatefulSet service name (for spec.serviceName)
*/}}
{{- define "app.statefulSetServiceName" -}}
{{- if .Values.statefulSet.serviceName -}}
{{- .Values.statefulSet.serviceName -}}
{{- else if .Values.service.headless.enabled -}}
{{- include "app.headlessServiceName" . -}}
{{- else -}}
{{- include "app.name" . -}}
{{- end -}}
{{- end }}

{{/*
Common pod template spec shared between Deployment and StatefulSet
*/}}
{{- define "app.podTemplateSpec" -}}
metadata:
  {{- with .Values.podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
    {{- with .Values.podLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- with .Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceAccountName: {{ include "app.serviceAccountName" . }}
  {{- with .Values.podSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  containers:
    - name: {{ .Chart.Name }}
      {{- with .Values.securityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      ports:
        - name: http
          containerPort: {{ .Values.containerPort }}
          protocol: TCP
      {{- with .Values.livenessProbe }}
      livenessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.readinessProbe }}
      readinessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.startupProbe }}
      startupProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.resources }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumeMounts:
        {{- if and .Values.configMap.enabled .Values.configMap.mountPath }}
        - name: {{ .Values.configMap.volumeName }}
          mountPath: {{ .Values.configMap.mountPath }}
        {{- end }}
        {{- with .Values.volumeMounts }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
  volumes:
    {{- if and .Values.configMap.enabled .Values.configMap.mountPath }}
    - name: {{ .Values.configMap.volumeName }}
      configMap:
        name: {{ include "app.name" . }}
    {{- end }}
    {{- with .Values.volumes }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
