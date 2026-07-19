{{/*
Mirrors the subchart's litellm.fullname logic so wrapper-created
resources (secrets, PostgreSQL) use the same name prefix the subchart
expects. The subchart alias is "litellm", so $name = "litellm".
*/}}
{{- define "litellm-openshift.litellm-fullname" -}}
{{- $name := "litellm" }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
PostgreSQL service name
*/}}
{{- define "postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "litellm-openshift.litellm-fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
PostgreSQL selector labels
*/}}
{{- define "postgresql.selectorLabels" -}}
app.kubernetes.io/name: postgresql
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
PostgreSQL labels
*/}}
{{- define "postgresql.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "postgresql.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Generate PostgreSQL password
*/}}
{{- define "postgresql.password" -}}
{{- if .Values.postgresql.auth.password }}
{{- .Values.postgresql.auth.password }}
{{- else }}
{{- randAlphaNum 16 }}
{{- end }}
{{- end }}
