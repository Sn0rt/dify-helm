{{- define "dify.api.credentials" -}}
# A secret key that is used for securely signing the session cookie and encrypting sensitive information on the database. You can generate a strong key using `openssl rand -base64 42`.
SECRET_KEY: {{ .Values.api.secretKey | b64enc | quote }}
{{- if .Values.sandbox.enabled }}
CODE_EXECUTION_API_KEY: {{ .Values.sandbox.auth.apiKey | b64enc | quote }}
{{- end }}
{{ include "dify.mail.credentials" . }}
{{- if .Values.pluginDaemon.enabled }}
PLUGIN_DAEMON_KEY: {{ .Values.pluginDaemon.auth.serverKey | b64enc | quote }}
INNER_API_KEY_FOR_PLUGIN: {{ .Values.pluginDaemon.auth.difyApiKey | b64enc | quote }}
{{- end }}
{{- end }}

{{- define "dify.worker.credentials" -}}
SECRET_KEY: {{ .Values.api.secretKey | b64enc | quote }}
{{ include "dify.mail.credentials" . }}
{{- if .Values.pluginDaemon.enabled }}
PLUGIN_DAEMON_KEY: {{ .Values.pluginDaemon.auth.serverKey | b64enc | quote }}
INNER_API_KEY_FOR_PLUGIN: {{ .Values.pluginDaemon.auth.difyApiKey | b64enc | quote }}
{{- end }}
{{- end }}

{{- define "dify.web.credentials" -}}
{{- end }}

{{- define "dify.db.credentials" -}}
{{- if .Values.externalPostgres.enabled }}
DB_USERNAME: {{ .Values.externalPostgres.username | b64enc | quote }}
DB_PASSWORD: {{ .Values.externalPostgres.password | b64enc | quote }}
{{- else if .Values.postgresql.enabled }}
  {{ with .Values.postgresql.global.postgresql.auth }}
  {{- if empty .username }}
DB_USERNAME: {{ print "postgres" | b64enc | quote }}
DB_PASSWORD: {{ .postgresPassword | b64enc | quote }}
  {{- else }}
DB_USERNAME: {{ .username | b64enc | quote }}
DB_PASSWORD: {{ .password | b64enc | quote }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "dify.s3.credentials" -}}
{{- if and .Values.externalS3.enabled (not .Values.externalSecret.enabled)}}
S3_ACCESS_KEY: {{ .Values.externalS3.accessKey | b64enc | quote }}
S3_SECRET_KEY: {{ .Values.externalS3.secretKey | b64enc | quote }}
{{- end }}
{{- end }}

{{- define "dify.storage.credentials" -}}
{{- include "dify.s3.credentials" . }}
{{- if .Values.externalAzureBlobStorage.enabled }}
# The Azure Blob storage configurations, only available when STORAGE_TYPE is `azure-blob`.
AZURE_BLOB_ACCOUNT_KEY: {{ .Values.externalAzureBlobStorage.key | b64enc | quote }}
{{- else if .Values.externalOSS.enabled }}
ALIYUN_OSS_ACCESS_KEY: {{ .Values.externalOSS.accessKey | b64enc | quote }}
ALIYUN_OSS_SECRET_KEY: {{ .Values.externalOSS.secretKey | b64enc | quote }}
{{- else if .Values.externalGCS.enabled }}
GOOGLE_STORAGE_SERVICE_ACCOUNT_JSON_BASE64: {{ .Values.externalGCS.serviceAccountJsonBase64 | b64enc | quote }}
{{- else if .Values.externalCOS.enabled }}
TENCENT_COS_SECRET_KEY: {{ .Values.externalCOS.secretKey| b64enc | quote }}
{{- else if .Values.externalOBS.enabled }}
HUAWEI_OBS_ACCESS_KEY: {{ .Values.externalOBS.accessKey | b64enc | quote }}
HUAWEI_OBS_SECRET_KEY: {{ .Values.externalOBS.secretKey | b64enc | quote }}
{{- else if .Values.externalTOS.enabled }}
VOLCENGINE_TOS_SECRET_KEY: {{ .Values.externalTOS.secretKey | b64enc | quote }}
{{- else }}
{{- end }}
{{- end }}

{{- define "dify.redis.credentials" -}}
{{- if and .Values.externalRedis.enabled (not .Values.externalSecret.enabled) }}
  {{- with .Values.externalRedis }}
REDIS_HOST: {{ .host | b64enc | quote }}
REDIS_PORT: {{ .port | toString | b64enc | quote }}
REDIS_USERNAME: {{ .username | b64enc | quote }}
REDIS_PASSWORD: {{ .password | b64enc | quote }}
REDIS_USE_SSL: {{ .useSSL | toString | b64enc | quote }}
REDIS_DB: {{ "0" | b64enc | quote }}
  {{- end }}
{{- else if .Values.redis.enabled }}
{{- $redisHost := printf "%s-redis-master" .Release.Name -}}
  {{- with .Values.redis }}
REDIS_HOST: {{ $redisHost | b64enc | quote }}
REDIS_PORT: {{ .master.service.ports.redis | toString | b64enc | quote }}
REDIS_USERNAME: {{ print "" | b64enc | quote }}
REDIS_PASSWORD: {{ .auth.password | b64enc | quote }}
REDIS_USE_SSL: {{ .tls.enabled | toString | b64enc | quote }}
REDIS_DB: {{ "0" | b64enc | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "dify.celery.credentials" -}}
# Use redis as the broker, and redis db 1 for celery broker.
{{- if and .Values.externalRedis.enabled (not .Values.externalSecret.enabled) }}
  {{- with .Values.externalRedis }}
    {{- $scheme := "redis" }}
    {{- if .useSSL }}
      {{- $scheme = "rediss" }}
    {{- end }}
CELERY_BROKER_URL: {{ printf "%s://%s:%s@%s:%v/1" $scheme .username .password .host .port | b64enc | quote }}
  {{- end }}
{{- else if .Values.redis.enabled }}
{{- $redisHost := printf "%s-redis-master" .Release.Name -}}
  {{- with .Values.redis }}
CELERY_BROKER_URL: {{ printf "redis://:%s@%s:%v/1" .auth.password $redisHost .master.service.ports.redis | b64enc | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "dify.vectordb.credentials" -}}
{{- if and .Values.externalElasticsearch.enabled (not .Values.externalSecret.enabled) }}
  {{- with .Values.externalElasticsearch }}
VECTOR_STORE: {{ "elasticsearch" | b64enc | quote }}
ELASTICSEARCH_HOST: {{ .host | b64enc | quote }}
ELASTICSEARCH_PORT: {{ .port | toString | b64enc | quote }}
ELASTICSEARCH_USERNAME: {{ .username | b64enc | quote }}
ELASTICSEARCH_PASSWORD: {{ .password | b64enc | quote }}
  {{- end }}
{{- else if and .Values.externalWeaviate.enabled (not .Values.externalSecret.enabled) }}
  {{- with .Values.externalWeaviate }}
VECTOR_STORE: {{ "weaviate" | b64enc | quote }}
WEAVIATE_ENDPOINT: {{ .endpoint | b64enc | quote }}
WEAVIATE_API_KEY: {{ .apiKey | b64enc | quote }}
  {{- end }}
{{- else if and .Values.externalQdrant.enabled (not .Values.externalSecret.enabled) }}
  {{- with .Values.externalQdrant }}
VECTOR_STORE: {{ "qdrant" | b64enc | quote }}
QDRANT_URL: {{ .endpoint | b64enc | quote }}
QDRANT_API_KEY: {{ .apiKey | b64enc | quote }}
QDRANT_CLIENT_TIMEOUT: {{ .timeout | toString | b64enc | quote }}
QDRANT_GRPC_ENABLED: {{ .grpc.enabled | toString | b64enc | quote }}
QDRANT_GRPC_PORT: {{ .grpc.port | toString | b64enc | quote }}
  {{- end }}
{{- else if and .Values.externalMilvus.enabled (not .Values.externalSecret.enabled) }}
  {{- with .Values.externalMilvus }}
VECTOR_STORE: {{ "milvus" | b64enc | quote }}
MILVUS_URI: {{ .uri | b64enc | quote }}
MILVUS_DATABASE: {{ .database | b64enc | quote }}
MILVUS_TOKEN: {{ .token | b64enc | quote }}
  {{- end }}
{{- else if and .Values.externalPgvector.enabled (not .Values.externalSecret.enabled) }}
  {{- with .Values.externalPgvector }}
VECTOR_STORE: {{ "pgvector" | b64enc | quote }}
PGVECTOR_HOST: {{ .address | b64enc | quote }}
PGVECTOR_PORT: {{ .port | toString | b64enc | quote }}
PGVECTOR_DATABASE: {{ .dbName | b64enc | quote }}
PGVECTOR_USERNAME: {{ .username | b64enc | quote }}
PGVECTOR_PASSWORD: {{ .password | b64enc | quote }}
  {{- end }}
{{- else if and .Values.externalTencentVectorDB.enabled (not .Values.externalSecret.enabled) }}
  {{- with .Values.externalTencentVectorDB }}
VECTOR_STORE: {{ "tencent" | b64enc | quote }}
TENCENT_VECTOR_DB_URL: {{ .url | b64enc | quote }}
TENCENT_VECTOR_DB_API_KEY: {{ .apiKey | b64enc | quote }}
TENCENT_VECTOR_DB_TIMEOUT: {{ .timeout | toString | b64enc | quote }}
TENCENT_VECTOR_DB_USERNAME: {{ .username | b64enc | quote }}
TENCENT_VECTOR_DB_DATABASE: {{ .database | b64enc | quote }}
TENCENT_VECTOR_DB_SHARD: {{ .shard | toString | b64enc | quote }}
TENCENT_VECTOR_DB_REPLICAS: {{ .replicas | toString | b64enc | quote }}
  {{- end }}
{{- else if and .Values.externalMyScaleDB.enabled (not .Values.externalSecret.enabled) }}
  {{- with .Values.externalMyScaleDB }}
VECTOR_STORE: {{ "myscale" | b64enc | quote }}
MYSCALE_HOST: {{ .host | b64enc | quote }}
MYSCALE_PORT: {{ .port | toString | b64enc | quote }}
MYSCALE_USER: {{ .username | b64enc | quote }}
MYSCALE_PASSWORD: {{ .password | b64enc | quote }}
MYSCALE_DATABASE: {{ .database | b64enc | quote }}
MYSCALE_FTS_PARAMS: {{ .ftsParams | b64enc | quote }}
  {{- end }}
{{- else if and .Values.externalTableStore.enabled (not .Values.externalSecret.enabled) }}
  {{- with .Values.externalTableStore }}
VECTOR_STORE: {{ "tablestore" | b64enc | quote }}
TABLESTORE_ENDPOINT: {{ .endpoint | b64enc | quote }}
TABLESTORE_INSTANCE_NAME: {{ .instanceName | b64enc | quote }}
TABLESTORE_ACCESS_KEY_ID: {{ .accessKeyId | b64enc | quote }}
TABLESTORE_ACCESS_KEY_SECRET: {{ .accessKeySecret | b64enc | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "dify.mail.credentials" -}}
{{- if eq .Values.api.mail.type "resend" }}
RESEND_API_KEY: {{ .Values.api.mail.resend.apiKey | b64enc | quote }}
{{- else if eq .Values.api.mail.type "smtp" }}
# Mail configuration for SMTP
SMTP_USERNAME: {{ .Values.api.mail.smtp.username | b64enc | quote }}
SMTP_PASSWORD: {{ .Values.api.mail.smtp.password | b64enc | quote }}
{{- end }}
{{- end }}

{{- define "dify.sandbox.credentials" -}}
API_KEY: {{ .Values.sandbox.auth.apiKey | b64enc | quote }}
{{- end }}

{{- define "dify.pluginDaemon.credentials" -}}
{{ include "dify.pluginDaemon.storage.credentials" . }}
SERVER_KEY: {{ .Values.pluginDaemon.auth.serverKey | b64enc | quote }}
DIFY_INNER_API_KEY: {{ .Values.pluginDaemon.auth.difyApiKey | b64enc | quote }}
{{- end }}

{{- define "dify.pluginDaemon.storage.credentials" -}}
{{- if and .Values.externalS3.enabled .Values.externalS3.bucketName.pluginDaemon }}
AWS_ACCESS_KEY: {{ .Values.externalS3.accessKey | b64enc | quote }}
AWS_SECRET_KEY: {{ .Values.externalS3.secretKey | b64enc | quote }}
{{- else if and .Values.externalOSS.enabled .Values.externalOSS.bucketName.pluginDaemon }}
ALIYUN_OSS_ACCESS_KEY_SECRET: {{ .Values.externalOSS.secretKey | b64enc | quote }}
{{- else if and .Values.externalGCS.enabled .Values.externalGCS.bucketName.pluginDaemon }}
GCS_CREDENTIALS: {{ .Values.externalGCS.serviceAccountJsonBase64 | b64enc | quote }}
{{- else if and .Values.externalCOS.enabled .Values.externalCOS.bucketName.pluginDaemon }}
TENCENT_COS_SECRET_KEY: {{ .Values.externalCOS.secretKey | b64enc | quote }}
{{- else if and .Values.externalOBS.enabled .Values.externalOBS.bucketName.pluginDaemon }}
HUAWEI_OBS_SECRET_KEY: {{ .Values.externalOBS.secretKey | b64enc | quote }}
{{- else if and .Values.externalTOS.enabled .Values.externalTOS.bucketName.pluginDaemon }}
PLUGIN_VOLCENGINE_TOS_SECRET_KEY: {{ .Values.externalTOS.secretKey | b64enc | quote }}
{{- end }}
{{- end }}
