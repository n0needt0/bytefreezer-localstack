{{/*
Expand the name of the chart.
*/}}
{{- define "localstack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "localstack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "localstack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "localstack.labels" -}}
helm.sh/chart: {{ include "localstack.chart" . }}
{{ include "localstack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "localstack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "localstack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "localstack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "localstack.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
LocalStack environment variables
*/}}
{{- define "localstack.env" -}}
- name: SERVICES
  value: {{ .Values.localstack.env.services | quote }}
- name: DEBUG
  value: {{ .Values.localstack.env.debug | quote }}
- name: PERSISTENCE
  value: {{ .Values.localstack.env.persistence | quote }}
- name: DOCKER_HOST
  value: "unix:///var/run/docker.sock"
- name: DATA_DIR
  value: {{ .Values.localstack.env.dataDir | quote }}
- name: HOSTNAME_EXTERNAL
  value: {{ printf "%s-internal.%s.svc.cluster.local" (include "localstack.fullname" .) .Values.namespace.name | quote }}
- name: SKIP_INFRA_DOWNLOADS
  value: {{ .Values.localstack.env.skipInfraDownloads | quote }}
{{- end }}

{{/*
PVC name
*/}}
{{- define "localstack.pvcName" -}}
{{- printf "%s-data-pvc" (include "localstack.fullname" .) }}
{{- end }}

{{/*
ConfigMap name
*/}}
{{- define "localstack.configMapName" -}}
{{- printf "%s-config" (include "localstack.fullname" .) }}
{{- end }}

{{/*
MetalLB address pool name
*/}}
{{- define "localstack.metallbPoolName" -}}
{{- .Values.metallb.addressPool.name | default "localstack-pool" }}
{{- end }}