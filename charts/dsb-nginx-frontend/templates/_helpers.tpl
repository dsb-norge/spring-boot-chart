{{/*
This function takes a yaml tree, and outputs a list of fully qualified properties.

Example:

root:
    test1: 1
    test2: 2

becomes

  root.test1: 1
  root.test2: 2

Very useful for converting yaml files to ConfigMap or Secrets.

See https://stackoverflow.com/questions/60184221/convert-yaml-to-property-file-in-helm-template
*/}}
{{- define "envify" -}}
{{- $prefix := index . 0 -}}
{{- $value := index . 1 -}}
{{- if kindIs "map" $value -}}
  {{- range $k, $v := $value -}}
    {{- if $prefix -}}
        {{- template "envify" (list (printf "%s.%s" $prefix $k) $v) -}}
    {{- else -}}
        {{- template "envify" (list (printf "%s" $k) $v) -}}
    {{- end -}}
  {{- end -}}
{{- else -}}
    {{ $prefix | indent 2 }}: {{ $value | quote }}
{{ end -}}
{{- end -}}
