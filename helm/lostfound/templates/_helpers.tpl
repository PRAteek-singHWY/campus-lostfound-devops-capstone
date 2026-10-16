{{- define "lostfound.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "lostfound.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
environment: {{ .Values.environment }}
{{- end -}}

{{/* per-tier selector labels; usage: include "lostfound.selector" (dict "ctx" . "tier" "backend") */}}
{{- define "lostfound.selector" -}}
app.kubernetes.io/name: {{ .ctx.Chart.Name }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .tier }}
{{- end -}}

{{- define "lostfound.dbSecretName" -}}
{{- if .Values.postgres.existingSecret -}}{{ .Values.postgres.existingSecret }}{{- else -}}{{ include "lostfound.fullname" . }}-db{{- end -}}
{{- end -}}

{{- define "lostfound.backendImage" -}}
{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag | default .Chart.AppVersion }}
{{- end -}}

{{- define "lostfound.frontendImage" -}}
{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag | default .Chart.AppVersion }}
{{- end -}}
