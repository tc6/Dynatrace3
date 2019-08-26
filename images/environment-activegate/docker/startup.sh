#!/usr/bin/env bash

verify() {
  if [ -z "${!1}" ]; then
    echo "Environment variable \"$1\" is required but has not been set"
    exit 1
  fi
}

parseParams() {
  local -r request_url="$DT_API_URL/v1/deployment/installer/agent/connectioninfo?Api-Token=$DT_PAAS_TOKEN"
  local -r response=$(curl -s --write-out "\\n%{http_code}" "$request_url")
  local -r http_code=${response##*$'\n'}
  case $http_code in
  200) ;;
  000 | 302 | 404)
    echo "Not Found! Make sure the provided URL is correct."
    exit 1
    ;;
  401)
    echo "Forbidden! Make sure the provided token is valid and of type \"PaaS Token\"."
    exit 1
    ;;
  *)
    echo "ERROR: server answered with status code \"$http_code\""
    exit 1
    ;;
  esac

  local -r body=${response%$'\n'*}

  echo "\
server_nodes = 1:[$(jq -r '.communicationEndpoints | join(", ")' <<<"$body")]
" >/app/config/cluster.properties

  echo "\
tenantUUID = $(jq -r '.tenantUUID' <<<"$body")
tenantToken = $(jq -r '.tenantToken' <<<"$body")
" >/app/config/instance.properties

  sed -e '/\[collector\]/r'<(
    echo "configured = true"
    jq -r '.communicationEndpoints[]' <<<"$body" | sed 's/^/seedServerUrl = /'
  ) -i /app/config/config.properties
}

writeDumpConfig() {
  local -r dump_dir="/app/gateway/launcher/dump"
  local dump_storage
  dump_storage=$DT_DUMP_STORAGE

  case $1 in
  cf)
    local -r cf_mount=$(echo "$VCAP_SERVICES" | jq -r '."fs-storage" | .[].volume_mounts | .[].container_dir')
    if [ -d "$cf_mount" ]; then
      mkdir -p ${dump_dir%/*}
      ln -s "$cf_mount" $dump_dir
    fi
    ;;
  k8s)
    if [ -d "$dump_dir" ]; then
      local -ri pvc_size=$(df -B G $dump_dir | sed -n '2 s/^[^ ]* *\([0-9]*\).*/\1/p')
      dump_storage=$((pvc_size - 1))
    fi
    ;;
  default)
    echo "unsupported platform"
    exit 1
    ;;
  esac

  if [ "$dump_storage" -le 0 ]; then
    echo "volume too small for memory dumps"
    exit 1
  fi

  echo "
[collector]
DumpSupported = true

[dump]
dumpDir = dump
maxSizeGb = $dump_storage
maxAgeDays = 7
maxConcurrentUploads = 5
downloadUrl = https://$DT_AG_HOST
" >>/app/config/custom.properties
}

handleCF() {
  DT_AG_HOST=$(echo "$VCAP_APPLICATION" | jq -r '.uris | .[]')
  echo "\
[connectivity]
dnsEntryPoint = https://$DT_AG_HOST

[com.compuware.apm.webserver]
port-ssl = 0
port = 9999
" >/app/config/custom.properties

  DT_DUMP_STORAGE=${DT_DUMP_STORAGE:-0}
  if [[ "$DT_DUMP_STORAGE" -gt 0 ]]; then
    writeDumpConfig "cf"
  fi
}

handleK8s() {
  if [ "$DT_AG_HOST_EXTERNAL" = "true" ]; then
    echo "\
[connectivity]
dnsEntryPoint = https://$DT_AG_HOST

[com.compuware.apm.webserver]
port-ssl = 0
port = 9999
" >/app/config/custom.properties
  else
    echo "\
[connectivity]
dnsEntryPoint = https://$(hostname -i):9998

[com.compuware.apm.webserver]
port-ssl = 9998
port = 9999
" >/app/config/custom.properties
  fi

  /app/gateway/jre/bin/keytool -importcert -file "/run/secrets/kubernetes.io/serviceaccount/ca.crt" -keystore "/app/gateway/jre/lib/security/cacerts" -storepass "changeit" -noprompt

  if [ "$DT_AG_HOST" ]; then
    writeDumpConfig "k8s"
  fi
}

verify "DT_API_URL"
verify "DT_PAAS_TOKEN"

parseParams

if [ "$VCAP_APPLICATION" ]; then
  handleCF
else
  handleK8s
fi

/app/gateway/Dynatrace-Gateway -XX:ErrorFile="/app/log/hs_err_pid_%p.log" -logdir "/app/log" -CONFIG_DIR "/app/config" -LOG_DIR "/app/log" -TEMP_DIR "/app/tmp"
