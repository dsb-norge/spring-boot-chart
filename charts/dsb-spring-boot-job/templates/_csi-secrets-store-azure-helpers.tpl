{{/*
  -----------------------------------------------------------------------------------
  Various helpers for Azure Key Vault Provider for Secrets Store CSI driver
  ie. to support mounting objects from Azure Key Vaults.
  'dackvp' is an abbreviation for 'dsb-azure-csi-key-vault-provider'
  -----------------------------------------------------------------------------------
*/}}


{{/*
  "Constants" templates
  -----------------------------------------------------------------------------------
*/}}

{{- define "dackvp.get-kv-object-types" -}}
  {{- (dict
    "output" (tuple
      "keys"
      "secrets"
      "certs"
    )) | toYaml | nindent 0 -}}
{{- end -}}

{{- define "dackvp.get-kv-object-types-map-to-singular" -}}
  {{- /* map from ".Values object type" to "secrets store provider type" */ -}}
  {{- dict "output" (dict
    "keys"    "key"
    "secrets" "secret"
    "certs"   "cert"
    ) | toYaml | nindent 0 -}}
{{- end -}}

{{- define "dackvp.get-kv-default-values-names" -}}
  {{- (dict
    "output" (tuple
      "tenantId"
      "clientId"
      "kvName"
    )) | toYaml | nindent 0 -}}
{{- end -}}


{{/*
  Naming templates
  -----------------------------------------------------------------------------------
*/}}

{{/*
  Return secret class provider name,
  given release name, vault configuration and vault name

  Force re-creation of secret provider on each deploy by generating name from hash of config.
  In combination with forcing k8s secrets to be re-created on each deploy this in turn forces any
  changes to environment variable name(s) to be synced.
*/}}
{{- define "dackvp.secret-provider-class-name" -}}
  {{- $releaseName := index . 0 -}}
  {{- $vaultConfig := index . 1 -}}
  {{- $configHash := $vaultConfig | toString | sha256sum | trunc 8 -}}
  {{- printf "%s-kv-provider-%s-%s" $releaseName $configHash $vaultConfig.kvName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
  Return secret provider volume name,
  given release name and vault name.

  Attempt to make name unique by generating from hash of config, this mitigates situations
  where the same voult is mounted more than one time.
*/}}
{{- define "dackvp.secret-provider-volume-name" -}}
  {{- $releaseName := index . 0 -}}
  {{- $vaultConfig := index . 1 -}}
  {{- $configHash := $vaultConfig | toString | sha256sum | trunc 8 -}}
  {{- printf "%s-kv-volume-%s-%s" $releaseName $configHash $vaultConfig.kvName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
  Return kubernetes secret name,
  given release name, vault configuration and vault name

  Force re-creation of k8s secret on each deploy by generating name from hash of config.
  This in turn forces any changes to environment variable name(s) to be synced.
*/}}
{{- define "dackvp.kubernetes-secret-name" -}}
  {{- $releaseName := index . 0 -}}
  {{- $vaultConfig := index . 1 -}}
  {{- $configHash := $vaultConfig | toString | sha256sum | trunc 8 -}}
  {{- printf "%s-kv-objects-%s-%s" $releaseName $configHash $vaultConfig.kvName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
  Return kubernetes config map name,
  given release name, vault configuration and vault name

  Force re-creation of k8s config map on each deploy by generating name from hash of config.
  This in turn forces any changes to environment variable name(s) to be synced.
*/}}
{{- define "dackvp.kubernetes-config-map-name" -}}
  {{- $releaseName := index . 0 -}}
  {{- $vaultConfig := index . 1 -}}
  {{- $configHash := $vaultConfig | toString | sha256sum | trunc 8 -}}
  {{- printf "%s-kv-file-envs-%s-%s" $releaseName $configHash $vaultConfig.kvName | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
  "Data" templates
  -----------------------------------------------------------------------------------
*/}}

{{/*
  this takes the vaults definintion from .Values and "enriches" it
  the idea is that the output of this template contains all data needed to loop and
  render all the things.
*/}}
{{- define "dackvp.vaults-enriched" -}}
  {{- $vaultsDef := index . 0 -}}
  {{- $defaultValues := index . 1 -}}
  {{- $releaseName := index . 2 -}}
  {{- $outVaults := $vaultsDef -}}
  {{- $kvDefaultValuesNames := (include "dackvp.get-kv-default-values-names" (list) | fromYaml).output -}}
  {{- range $vaultKey, $vaultDef := $vaultsDef -}}

    {{- /*
      use values from '.defaultValues' when not defined on the KV object
    */ -}}
    {{- range $defaultValueName := $kvDefaultValuesNames -}}
      {{- $defaultValue := include "dackvp.default-values-fallback" (list $defaultValueName $vaultDef $vaultKey $defaultValues ) -}}
      {{- $_ := set $vaultDef $defaultValueName $defaultValue -}}
    {{- end -}}

    {{- /*
      create name for csi secrets store provider class
      add only if not already exists to avoid hashes to differ each time this
      template is called
    */ -}}
    {{- if not (hasKey $vaultDef "secretProviderClassName") -}}
      {{- $secretProviderClassName := include "dackvp.secret-provider-class-name" (list $releaseName $vaultDef) -}}
      {{- $_ := set $vaultDef "secretProviderClassName" $secretProviderClassName -}}
    {{- end -}}

    {{- /*
      create kubernetes secret name for csi secrets store provider
      add only if not already exists to avoid hashes to differ each time this
      template is called
    */ -}}
    {{- if not (hasKey $vaultDef "k8sSecretName") -}}
      {{- $k8sSecretName := include "dackvp.kubernetes-secret-name" (list $releaseName $vaultDef) -}}
      {{- $_ := set $vaultDef "k8sSecretName" $k8sSecretName -}}
    {{- end -}}

    {{- /*
      create kubernetes config map name for csi secrets store provider
      add only if not already exists to avoid hashes to differ each time this
      template is called
    */ -}}
    {{- if not (hasKey $vaultDef "k8sConfigMapName") -}}
      {{- $k8sConfigMapName := include "dackvp.kubernetes-config-map-name" (list $releaseName $vaultDef) -}}
      {{- $_ := set $vaultDef "k8sConfigMapName" $k8sConfigMapName -}}
    {{- end -}}

    {{- /*
      create volume name for kubernetes, used when mounting from csi secrets store provider
      add only if not already exists to avoid hashes to differ each time this
      template is called
    */ -}}
    {{- if not (hasKey $vaultDef "k8sVolumeName") -}}
      {{- $k8sVolumeName := include "dackvp.secret-provider-volume-name" (list $releaseName $vaultDef) -}}
      {{- $_ := set $vaultDef "k8sVolumeName" $k8sVolumeName -}}
    {{- end -}}

    {{- /* update the output object */ -}}
    {{- $_ := set $outVaults $vaultKey $vaultDef -}}
  {{- end -}}

  {{- /* return map with default values and names added */ -}}
  {{- dict "output" $outVaults | toYaml | nindent 0 -}}
{{- end -}}

{{/*
  This serves several purposes:
    1. Given a field name:
      a. Return the value from $vaultDef if key exists
      b. Return the value from $defaultValues if key did not exist in $vaultDef
      c. Make sure the field name exists in at least one of the maps
    2. Make sure the value to return is not empty
*/}}
{{- define "dackvp.default-values-fallback" -}}
  {{- $key := index . 0 -}}
  {{- $vaultDef := index . 1 -}}
  {{- $vaultKeyName := index . 2 -}}
  {{- $defaultValues := index . 3 -}}
  {{- if and (not (hasKey $vaultDef $key)) (not (hasKey $defaultValues $key)) -}}
    {{- fail (printf "ERROR: '%s' not defined for '%s' and not defined in '.azureKeyVault.defaultValues'" $key $vaultKeyName) -}}
  {{- end -}}
  {{- $value := default (get $defaultValues $key) (get $vaultDef $key) -}}
  {{- if empty $value -}}
    {{- fail (printf "ERROR: The field '%s' is empty for key vault '%s'" $key $vaultKeyName) -}}
  {{- end -}}
  {{- print $value -}}
{{- end -}}

{{/*
  Validate and return key vault objects definition from .Values
  Given a vault yaml-key name, vault configuration and the type of kv object
  def to return (one of those in "dackvp.get-kv-object-types").
  Also checks for existence of one required field.
  Also adds a field 'alias' to each of the definitions, this is used by the
  csi secrets store provider.

  Consumer must call 'fromYaml' and read the property 'output' of the result.
*/}}
{{- define "dackvp.get-kv-objects-def" -}}
  {{- $vaultKeyName := index . 0 -}}
  {{- $vaultDef := index . 1 -}}
  {{- $objectType := index . 2 -}}

  {{- /* this field is required */ -}}
  {{- $objRequiredField := "nameInKv" -}}

  {{- /* map from ".Values object type" to secrets store provider type */ -}}
  {{- $objectTypeSingularMap := (include "dackvp.get-kv-object-types-map-to-singular" (list) | fromYaml).output -}}
  {{- $objectTypeSingular := (get $objectTypeSingularMap $objectType) -}}

  {{- if hasKey $vaultDef $objectType -}}
    {{- if not (get $vaultDef $objectType) | kindIs "slice" -}}
      {{- fail (printf "ERROR: '%s' in values is defined with wrong type '%s' for key vault '%s', expected 'slice'." $objectType (kindOf (get $vaultDef $objectType)) $vaultKeyName ) -}}
      {{- /* return empty map */ -}}
      {{- dict "output" | toYaml | nindent 0 -}}
    {{- else -}}
      {{- $objDef := (get $vaultDef $objectType) -}}
      {{- range $obj := $objDef -}}

        {{- /* validate required field */ -}}
        {{- if not (hasKey $obj $objRequiredField) -}}
          {{- fail (printf "ERROR: required field '%s' is missing for one of the '%s' definitions for key vault '%s'." $objRequiredField $objectType $vaultKeyName ) -}}
        {{- end -}}

        {{- /*
          Additional validation below relating to the use of 'objectFormat' and 'objectEncoding' in the
          azure csi secrets store provider.
          ref. https://azure.github.io/secrets-store-csi-driver-provider-azure/docs/getting-started/usage/
        */ -}}

        {{- /* validate 'fileMountFormat' just for secret type */ -}}
        {{- if (and (hasKey $obj "fileMountFormat") (ne $objectType "secrets") ) -}}
          {{- fail (printf "ERROR: the use of 'fileMountFormat' is only supported for secrets, found in '%s' definitions for key vault '%s'." $objectType $vaultKeyName ) -}}
        {{- end -}}

        {{- /* validate 'fileMountFormat' supported types are pem and pfx, as of azure csi secrets store provider v1.2.0 */ -}}
        {{- if (hasKey $obj "fileMountFormat") -}}
          {{- if not (or (get $obj "fileMountFormat" | eq "pem") (get $obj "fileMountFormat" | eq "pfx") ) -}}
            {{- fail (printf "ERROR: 'fileMountFormat' must be one of [pem, pfx], got '%s' in '%s' definitions for key vault '%s'." (get $obj "fileMountFormat") $objectType $vaultKeyName ) -}}
          {{- end -}}
        {{- end -}}

        {{- /* validate 'secretEncoding' just for secret type */ -}}
        {{- if (and (hasKey $obj "secretEncoding") (ne $objectType "secrets") ) -}}
          {{- fail (printf "ERROR: the use of 'secretEncoding' is only supported for secrets, found in '%s' definitions for key vault '%s'." $objectType $vaultKeyName ) -}}
        {{- end -}}

        {{- /* validate no 'mountAsEnv' when 'secretEncoding=base64' or 'secretEncoding=hex' */ -}}
        {{- if (and (hasKey $obj "secretEncoding") (hasKey $obj "mountAsEnv") ) -}}
          {{- if (or ((get $obj "secretEncoding") | lower | eq "base64") (get $obj "secretEncoding" | lower | eq "hex") ) -}}
            {{- fail (printf "ERROR: do not combine the use of 'mountAsEnv' and 'secretEncoding=base64'. The csi secrets storage provider will fail to mount binary data in environment variable resulting in container failing to boot. 'mountAsEnv=%s' and 'secretEncoding=%s' found in '%s' definitions for key vault '%s'." (get $obj "mountAsEnv") (get $obj "secretEncoding") $objectType $vaultKeyName ) -}}
          {{- end -}}
        {{- end -}}

        {{- /*
          add alias field, used by the secrets provider
          produce alias from first 16 og sha 256 hash
          only add once, this is called multiple times
        */ -}}
        {{- if not (hasKey $obj "alias") -}}
          {{- $_ := set $obj "alias" ($obj | toString | sha256sum | trunc 16) -}}
        {{- end -}}

        {{- /*
          add object type field, used by the secrets provider
          only add once, this is called multiple times
        */ -}}
        {{- if not (hasKey $obj "objectType") -}}
          {{- $_ := set $obj "objectType" $objectTypeSingular -}}
        {{- end -}}

        {{- /*
          add mount path field, used for pod volumeMounts
          use value from .fileMountPath if specified, otherwise default to using hash path under /mnt
          only add once, this is called multiple times
        */ -}}
        {{- if not (hasKey $obj "volumeMountPath") -}}
          {{- if (hasKey $obj "fileMountPath") -}}
            {{- $_ := set $obj "volumeMountPath" (get $obj "fileMountPath") -}}
          {{- else -}}
            {{- /* file must be mounted to disk even if specification only defines 'mountAsEnv' */ -}}
            {{- /* otherwise the csi provider will not create kubernetes secret(s) from the kv object(s) */ -}}
            {{- if (or (hasKey $obj "fileMountPathEnvName") (hasKey $obj "mountAsEnv") ) -}}
              {{- $_ := set $obj "volumeMountPath" (printf "/mnt/%s/%s" ($vaultDef.kvName | sha256sum | trunc 16) (get $obj "alias")) -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}

      {{- /* return map with key vault objects definition */ -}}
      {{- dict "output" (get $vaultDef $objectType) | toYaml | nindent 0 -}}
    {{- end -}}
  {{- else -}}
    {{- /* return empty map */ -}}
    {{- dict "output" | toYaml | nindent 0 -}}
  {{- end -}}
{{- end -}}

{{/*
  Validate and return key vault objects definition from .Values that have a specific
  field defined.

  Given a vault yaml-key name, vault configuration, the type of kv object def
  to return (one of those in "dackvp.get-kv-object-types") and field name to that
  should be defined.

  Consumer must call 'fromYaml' and read the property 'output' of the result.
*/}}
{{- define "dackvp.internal-get-kv-objects-with-given-field" -}}
  {{- $vaultKeyName := index . 0 -}}
  {{- $vaultDef := index . 1 -}}
  {{- $objectType := index . 2 -}}
  {{- $mountFieldName := index . 3 -}}
  {{- $objectsDef := (include "dackvp.get-kv-objects-def" (list $vaultKeyName $vaultDef $objectType) | fromYaml).output -}}
  {{- "output:" | nindent 0 -}}
  {{/* Not slice means nothing found of givn type */}}
  {{- if not ($objectsDef | kindIs "slice" ) -}}
    {{- list | toYaml | nindent 2 -}}
  {{- else -}}
    {{- range $object := $objectsDef -}}
      {{- if (hasKey $object $mountFieldName) -}}
        {{- if not (get $object $mountFieldName) | kindIs "string" -}}
          {{- fail (printf "ERROR: the field '%s' in one of the '%s' definitions is defined with wrong type '%s' for key vault '%s', expected 'string'." $mountFieldName $objectType (kindOf (get $object $mountFieldName)) $vaultKeyName ) -}}
        {{- else -}}
          {{- if not (gt (get $object $mountFieldName | len) 0) -}}
            {{- fail (printf "ERROR: the field '%s' in one of the '%s' definitions has zero length for key vault '%s', expected length of 1 or more." $mountFieldName $objectType $vaultKeyName ) -}}
          {{- else -}}
            {{- $object | list | toYaml | nindent 2 -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
  Validate and return key vault objects definition from .Values that are configured
  to be mounted as environment variables.

  Given a vault yaml-key name, vault configuration and the type of kv object def
  to return (one of those in "dackvp.get-kv-object-types").

  Consumer must call 'fromYaml' and read the property 'output' of the result.
*/}}
{{- define "dackvp.get-kv-objects-to-mount-as-env" -}}
  {{- $vaultKeyName := index . 0 -}}
  {{- $vaultDef := index . 1 -}}
  {{- $objectType := index . 2 -}}
  {{- $mountFieldName := "mountAsEnv" -}}
  {{- $objectsDef := (include "dackvp.internal-get-kv-objects-with-given-field" (list $vaultKeyName $vaultDef $objectType $mountFieldName) | fromYaml).output -}}
  {{- if not ($objectsDef | kindIs "slice" ) -}}
    {{- dict "output" (list) | toYaml | nindent 0 -}}
  {{- else -}}
    {{- dict "output" $objectsDef | toYaml | nindent 0 -}}
  {{- end -}}
{{- end -}}

{{/*
  Validate and return key vault objects definition from .Values that are configured
  to be mounted as files.

  Given a vault yaml-key name, vault configuration and the type of kv object def
  to return (one of those in "dackvp.get-kv-object-types").

  Consumer must call 'fromYaml' and read the property 'output' of the result.
*/}}
{{- define "dackvp.get-kv-objects-to-mount-as-file" -}}
  {{- $vaultKeyName := index . 0 -}}
  {{- $vaultDef := index . 1 -}}
  {{- $objectType := index . 2 -}}
  {{- $mountFieldName := "volumeMountPath" -}}
  {{- $objectsDef := (include "dackvp.internal-get-kv-objects-with-given-field" (list $vaultKeyName $vaultDef $objectType $mountFieldName) | fromYaml).output -}}
    {{- if ($objectsDef | kindIs "slice" ) -}}
      {{- dict "output" $objectsDef | toYaml | nindent 0 -}}
    {{- else -}}
      {{- /* return map with empty list */ -}}
      {{- dict "output" (list) | toYaml | nindent 0 -}}
    {{- end -}}
{{- end -}}

{{/*
  Validate and return key vault objects definition from .Values that are configured
  to be mounted as files AND have their path mounted as environment variables.

  Given a vault yaml-key name, vault configuration and the type of kv object def
  to return (one of those in "dackvp.get-kv-object-types").

  Consumer must call 'fromYaml' and read the property 'output' of the result.
*/}}
{{- define "dackvp.get-kv-objects-to-mount-filepath-as-env" -}}
  {{- $vaultKeyName := index . 0 -}}
  {{- $vaultDef := index . 1 -}}
  {{- $objectType := index . 2 -}}
  {{- $mountFieldName := "fileMountPathEnvName" -}}
  {{- $objectsDef := (include "dackvp.internal-get-kv-objects-with-given-field" (list $vaultKeyName $vaultDef $objectType $mountFieldName) | fromYaml).output -}}
  {{- if not ($objectsDef | kindIs "slice" ) -}}
    {{- dict "output" (list) | toYaml | nindent 0 -}}
  {{- else -}}
    {{- dict "output" $objectsDef | toYaml | nindent 0 -}}
  {{- end -}}
{{- end -}}


{{/*
  Logic templates
  -----------------------------------------------------------------------------------
*/}}

{{/*
  Given a key vault definition decides if a csi secrets store provider resource should be rendered.
  Condition is that at least one object is defined (one of those in "dackvp.get-kv-object-types").
*/}}
{{- define "dackvp.should-render-secrets-store-provider" -}}
  {{- $vaultKeyName := index . 0 -}}
  {{- $vaultDef := index . 1 -}}
  {{- $kvObjectTypes := (include "dackvp.get-kv-object-types" (list) | fromYaml).output -}}
  {{- $shouldRender := dict "result" false -}}
  {{- range $objectType := $kvObjectTypes -}}
    {{- $objTypeDef := (include "dackvp.get-kv-objects-def" (list $vaultKeyName $vaultDef $objectType) | fromYaml).output -}}
    {{/* Not slice means nothing found of givn type */}}
    {{- if ($objTypeDef | kindIs "slice" ) -}}
      {{- $_ := set $shouldRender "result" (or $shouldRender.result (gt ($objTypeDef | len) 0) ) -}}
    {{- end -}}
  {{- end -}}
  {{- ternary "true" "" $shouldRender.result -}}
{{- end -}}

{{/*
  Given a key vault definition decides if kubernetes config map should
  be rendered for the csi secrets store provider.

  Condition is that at least one object is defined to be mounted as file
  AND have their path mounted as environment variables.
*/}}
{{- define "dackvp.should-render-kubernetes-config-map-from-csi-provider" -}}
  {{- $vaultKeyName := index . 0 -}}
  {{- $vaultDef := index . 1 -}}
  {{- $kvObjectTypes := (include "dackvp.get-kv-object-types" (list) | fromYaml).output -}}
  {{- $shouldRender := dict "result" false -}}
  {{- range $objectType := $kvObjectTypes -}}
    {{- $objToMount := (include "dackvp.get-kv-objects-to-mount-filepath-as-env" (list $vaultKeyName $vaultDef $objectType) | fromYaml).output -}}
    {{- $_ := set $shouldRender "result" (or $shouldRender.result (gt ($objToMount | len) 0) ) -}}
  {{- end -}}
  {{- ternary "true" "" $shouldRender.result -}}
{{- end -}}

{{/*
  Given a key vault definition decides if kubernetes secrets block should
  be rendered in the csi secrets store provider resource definition.

  Condition is that at least one object is defined to be mounted as env.
*/}}
{{- define "dackvp.should-render-kubernetes-secrets-from-csi-provider" -}}
  {{- $vaultKeyName := index . 0 -}}
  {{- $vaultDef := index . 1 -}}
  {{- $kvObjectTypes := (include "dackvp.get-kv-object-types" (list) | fromYaml).output -}}
  {{- $shouldRender := dict "result" false -}}
  {{- range $objectType := $kvObjectTypes -}}
    {{- $objToMount := (include "dackvp.get-kv-objects-to-mount-as-env" (list $vaultKeyName $vaultDef $objectType) | fromYaml).output -}}
    {{- $_ := set $shouldRender "result" (or $shouldRender.result (gt ($objToMount | len) 0) ) -}}
  {{- end -}}
  {{- ternary "true" "" $shouldRender.result -}}
{{- end -}}

{{/*
  Given a key vault definition decides if kubernetes secrets block should
  be rendered in the csi secrets store provider resource definition.

  Condition is that at least one object is defined to be mounted as env.
*/}}
{{- define "dackvp.should-render-kubernetes-volume-mounts-from-csi-provider" -}}
  {{- $vaultKeyName := index . 0 -}}
  {{- $vaultDef := index . 1 -}}
  {{- $kvObjectTypes := (include "dackvp.get-kv-object-types" (list) | fromYaml).output -}}
  {{- $shouldRender := dict "result" false -}}
  {{- range $objectType := $kvObjectTypes -}}
    {{- $objToMount := (include "dackvp.get-kv-objects-to-mount-as-file" (list $vaultKeyName $vaultDef $objectType) | fromYaml).output -}}
    {{- $_ := set $shouldRender "result" (or $shouldRender.result (gt ($objToMount | len) 0) ) -}}
  {{- end -}}
  {{- ternary "true" "" $shouldRender.result -}}
{{- end -}}


{{/*
  Render templates
  -----------------------------------------------------------------------------------
*/}}

{{/*
  This template renders the objects array in the spec.parameters.objects.array
  of the secrets-store.csi.x-k8s.io/v1/SecretProviderClass resource.
  ref. https://azure.github.io/secrets-store-csi-driver-provider-azure/docs/getting-started/usage/
*/}}
{{- define "dackvp.render-secrets-store-objects" -}}
  {{- $vaultKeyName := index . 0 -}}
  {{- $vaultDef := index . 1 -}}
  {{- $kvObjectTypes := (include "dackvp.get-kv-object-types" (list) | fromYaml).output -}}
  {{- range $objectType := $kvObjectTypes -}}
    {{- $objectsDef := (include "dackvp.get-kv-objects-def" (list $vaultKeyName $vaultDef $objectType) | fromYaml).output -}}
    {{/* Not slice means nothing found of givn type */}}
    {{- if ($objectsDef | kindIs "slice" ) -}}
      {{- range $object := $objectsDef }}
- |
  objectAlias: {{ $object.alias | quote }}
  objectName: {{ $object.nameInKv | quote }}
  objectType: {{ $object.objectType | quote }}
        {{- if (and ( $object.objectType | eq "secret" ) ( hasKey $object "fileMountFormat" ) ) -}}
        {{- /* objectFormat: the format of the Azure Key Vault object, supported types are pem and pfx. */ -}}
        {{- /* objectFormat: pfx is only supported with objectType: secret and PKCS12 or ECC certificates */ -}}
        {{- /* ref. https://azure.github.io/secrets-store-csi-driver-provider-azure/docs/getting-started/usage/ */}}
  objectFormat: {{ $object.fileMountFormat | quote }}
        {{- end -}}
        {{- if (and ( $object.objectType | eq "secret" ) ( hasKey $object "secretEncoding" ) ) -}}
        {{- /* objectEncoding: the encoding of the Azure Key Vault secret object, supported types are utf-8, hex and base64. */ -}}
        {{- /* This option is supported only with objectType: secret */ -}}
        {{- /* ref. https://azure.github.io/secrets-store-csi-driver-provider-azure/docs/getting-started/usage/ */}}
  objectEncoding: {{ $object.secretEncoding | quote }}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
  This template renders the secretObjects in the spec.secretObjects
  of the secrets-store.csi.x-k8s.io/v1/SecretProviderClass resource.
  creates K8s secret objects from mounted secrets
  ref. https://azure.github.io/secrets-store-csi-driver-provider-azure/docs/configurations/sync-with-k8s-secrets/
*/}}
{{- define "dackvp.render-kubernetes-secrets-data-block-in-csi-provider" -}}
  {{- $vaultKeyName := index . 0 -}}
  {{- $vaultDef := index . 1 -}}
  {{- $kvObjectTypes := (include "dackvp.get-kv-object-types" (list) | fromYaml).output -}}
  {{- range $objectType := $kvObjectTypes -}}
    {{- $objectsDef := (include "dackvp.get-kv-objects-to-mount-as-env" (list $vaultKeyName $vaultDef $objectType) | fromYaml).output -}}
    {{- range $object := $objectsDef }}
- key: {{ $object.mountAsEnv | quote }}
  objectName: {{ $object.alias | quote }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
  Renders the kubernetes secret and config map refs
  Should be called within the 'spec.containers[].env.envFrom' defintion
*/}}
{{- define "dackvp.render-kubernetes-env-config" -}}
  {{- $vaultsDef := index . 0 -}}
  {{- $defaultValues := index . 1 -}}
  {{- $releaseName := index . 2 -}}

  {{- /* loop over keyvaults and mount envs from csi kubernetes secrets */ -}}
  {{- $vaultsWithDefaultValues := (include "dackvp.vaults-enriched" (list $vaultsDef $defaultValues $releaseName) | fromYaml).output -}}
  {{- range $vaultKey, $vaultDef := $vaultsWithDefaultValues -}}
    {{- if (include "dackvp.should-render-kubernetes-secrets-from-csi-provider" (list $vaultKey $vaultDef) ) }}
- secretRef:
    name: {{ $vaultDef.k8sSecretName | quote }}
    {{- end -}}
    {{- if (include "dackvp.should-render-kubernetes-config-map-from-csi-provider" (list $vaultKey $vaultDef) ) }}
- configMapRef:
    name: {{ $vaultDef.k8sConfigMapName | quote }}
    {{- end -}}
  {{- end -}}{{- /* vaults loop */ -}}
{{- end -}}

{{/*
  Renders the kubernetes volume mounts configuration
  Should be called within the 'spec.containers[].volumeMounts' defintion
*/}}
{{- define "dackvp.render-kubernetes-volume-mounts" -}}
  {{- $vaultsDef := index . 0 -}}
  {{- $defaultValues := index . 1 -}}
  {{- $releaseName := index . 2 -}}

  {{- /* loop over keyvaults and mount csi volumes */ -}}
  {{- $vaultsWithDefaultValues := (include "dackvp.vaults-enriched" (list $vaultsDef $defaultValues $releaseName) | fromYaml).output -}}
  {{- range $vaultKey, $vaultDef := $vaultsWithDefaultValues -}}

    {{- /* loop over object types (key, secrets and keys) */ -}}
    {{- $kvObjectTypes := (include "dackvp.get-kv-object-types" (list) | fromYaml).output -}}
    {{- range $objectType := $kvObjectTypes -}}

      {{- /* if any files should be mounted, this will return them */ -}}
      {{- $objsToMount := (include "dackvp.get-kv-objects-to-mount-as-file" (list $vaultKey $vaultDef $objectType) | fromYaml).output -}}

      {{- /* loop files and mount */ -}}
      {{- range $obj := $objsToMount }}
- mountPath: {{ $obj.volumeMountPath | quote }}
  name: {{ $vaultDef.k8sVolumeName | quote }}
  readOnly: true
  subPath: {{ $obj.alias | quote }}
      {{- end -}}{{/* mount files loop */}}
    {{- end -}}{{/* object types loop */}}
  {{- end -}}{{/* vaults loop */}}
{{- end -}}

{{/*
  Renders the kubernetes volumes configuration
  Should be called within the 'spec.containers[].volumes' defintion
*/}}
{{- define "dackvp.render-kubernetes-volumes" -}}
  {{- $vaultsDef := index . 0 -}}
  {{- $defaultValues := index . 1 -}}
  {{- $releaseName := index . 2 -}}

  {{- /* loop over keyvaults and mount csi volumes */ -}}
  {{- $vaultsWithDefaultValues := (include "dackvp.vaults-enriched" (list $vaultsDef $defaultValues $releaseName) | fromYaml).output -}}
  {{- range $vaultKey, $vaultDef := $vaultsWithDefaultValues -}}
    {{- if (include "dackvp.should-render-secrets-store-provider" (list $vaultKey $vaultDef) ) }}
- csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: {{ $vaultDef.secretProviderClassName | quote }}
  name: {{ $vaultDef.k8sVolumeName | quote }}
    {{- end -}}{{/* should render */}}
  {{- end -}}{{/* vaults loop */}}
{{- end -}}
