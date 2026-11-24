{{/*
Chart name.
*/}}
{{- define "keycloak-client-provisioner.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Release fullname.
*/}}
{{- define "keycloak-client-provisioner.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "keycloak-client-provisioner.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Chart label.
*/}}
{{- define "keycloak-client-provisioner.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "keycloak-client-provisioner.labels" -}}
helm.sh/chart: {{ include "keycloak-client-provisioner.chart" . }}
app.kubernetes.io/name: {{ include "keycloak-client-provisioner.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels.
*/}}
{{- define "keycloak-client-provisioner.selectorLabels" -}}
app.kubernetes.io/name: {{ include "keycloak-client-provisioner.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Service account name.
*/}}
{{- define "keycloak-client-provisioner.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{- default (include "keycloak-client-provisioner.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
    {{- required "serviceAccount.name is required when serviceAccount.create is false" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Image reference.
*/}}
{{- define "keycloak-client-provisioner.image" -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- end -}}
