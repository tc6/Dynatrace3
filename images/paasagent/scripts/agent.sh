#!/bin/bash

declare -A log_levels=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)

log() {
    local log_message=$1
    local log_priority=${2:-INFO}

    #check if level exists
    if [[ ! ${log_levels[$log_priority]} ]]; then
        return 1
    fi
    #check if level is enough
    if [[ ${log_levels[$log_priority]} < ${log_levels[${LOGLEVEL:-INFO}]} ]]; then
        return 2
    fi

    #log to stderror if it was an error
    if [ "$log_priority" == ERROR ]
    then
        >&2 echo "${log_priority} : ${log_message}"
    else
        echo "${log_priority} : ${log_message}"
    fi
}

handled_exit(){
 local -r rc=$1
 if [ $rc == 0 ] ; then
   exit 0
 fi

 if [ "$DT_SKIP_ERRORS" == "true" ] ; then
  log "... skiperrors"
  exit 0
 else
  log "... failing" ERROR
  exit $1
 fi
}

read_vcap(){
  if [ -n "$VCAP_SERVICES"  ] ; then
    DT_API_TOKEN=$(echo "$VCAP_SERVICES" | jq -r '."user-provided"[] | select(.name == "dynatrace").credentials.apitoken')
    DT_API_URL=$(echo "$VCAP_SERVICES" | jq -r '."user-provided"[] | select(.name == "dynatrace").credentials.apiurl')
    DT_TENANT=$(echo "$VCAP_SERVICES" | jq -r '."user-provided"[] | select(.name == "dynatrace").credentials.environmentid')
    DT_SKIP_ERRORS=$(echo "$VCAP_SERVICES" | jq -r '."user-provided"[] | select(.name == "dynatrace").credentials.skiperrors')
    export DT_APPLICATION_ID=$(echo "$VCAP_APPLICATION" | jq -r '."application_name"')
    export DT_HOST_ID=$(echo "$VCAP_APPLICATION" | jq -r '."application_name"')_$CF_INSTANCE_INDEX
  fi
}

read_connection_info(){
  local -r tenant_token_url="$DT_API_URL/v1/deployment/installer/agent/connectioninfo?Api-Token=$DT_API_TOKEN"
  log "Connection info url: ${tenant_token_url}" DEBUG

  local -r response=$(curl -s --write-out "\\n%{http_code}" "$tenant_token_url")
  local -r http_status="${response##*$'\n'}"
  if [ "$http_status" != "200" ] ; then
     log "Could not receive connection infos from tenant. Http status($http_status) not equals 200" ERROR
     handled_exit 2
  fi
  local -r connection_info_json="${response%$'\n'*}"
  log "Tenant token received used: ${connection_info_json}" DEBUG

  export DT_TENANTTOKEN=$(echo "$connection_info_json" | jq -r '.tenantToken')
  export DT_CONNECTION_POINT=$(echo "$connection_info_json"  | jq -r '.communicationEndpoints | join(";")')
  export DT_CLUSTER_ID=${DT_CLUSTER_ID:-$DT_APPLICATION_ID}
}

write_ld_preload(){
  local -r agentPath=$(cat /opt/dynatrace/oneagent/manifest.json | jq -r '[."technologies"."process"."linux-x86-64"[] | select(.binarytype == "primary")]' | jq -r '.[0].path')
  if [ -z "$agentPath" ] ; then
   log "Dynatrace agentPath could not be determined, no instrumentation possible" ERROR
   handled_exit 3
  fi
  export LD_PRELOAD="/opt/dynatrace/oneagent/${agentPath}"
  log "LD_PRELOAD used: ${LD_PRELOAD}" DEBUG
  if [ -f /etc/ld.so.preload ] ; then
    grep -qxF "$LD_PRELOAD" /etc/ld.so.preload || echo "$LD_PRELOAD" >> /etc/ld.so.preload
  else
    echo "$LD_PRELOAD" >> /etc/ld.so.preload
  fi
}

start_using_agent_template(){
  log "Start Dynatrace agent using template"
  read_connection_info
  write_ld_preload
}

download_and_install_agent(){

   local -r download_url="$DT_API_URL/v1/deployment/installer/agent/unix/paas-sh/latest?flavor=default&include=all&bitness=64&arch=x86&Api-Token=${DT_API_TOKEN}"
   wget --quiet -O dynatrace-install.sh "${download_url}"
   if [ $? -ne 0 ] ; then
     log "Could not download agent from ${download_url}" | sed "s\\$DT_API_TOKEN\\xxxTOKENxxx\\g" ERROR
     handled_exit 2
   fi
   chmod +x dynatrace-install.sh
   ./dynatrace-install.sh
   write_ld_preload
}

remove_secrets(){
    rm dynatrace-install.sh
    rm /opt/dynatrace/oneagent/dynatrace-env.sh
    cat /opt/dynatrace/oneagent/manifest.json \
      | jq 'del(.tenantUUID, .tenantToken, .communicationEndpoints)' > /opt/dynatrace/oneagent/manifest.json.clean \
      && mv /opt/dynatrace/oneagent/manifest.json.clean /opt/dynatrace/oneagent/manifest.json
}

initialize_variables(){

  VCAP_TOKEN=$(echo "$VCAP_SERVICES" | jq -r '."user-provided"[] | select(.name == "dynatrace").credentials.apitoken')

  if [ -n "$VCAP_TOKEN" ] && [ -n "$DT_API_TOKEN" ]; then
    log "Dynatrace token provided via environment variables and user-provided service - data from user-provided service will be used." WARN
  fi

  if [ -n "$VCAP_TOKEN" ]; then
    log "Dynatrace service bound. Reading data from user-provided service."
    read_vcap
  fi

  if [ -z "$DT_API_TOKEN" ] || [ -z "$DT_API_URL" ]; then
    log "Dynatrace agent could not be configured, since required variables were not found." ERROR
    handled_exit 1
  fi

}

prepare(){
  initialize_variables
  download_and_install_agent
  remove_secrets
}

start(){
  initialize_variables

  if [ -f /opt/dynatrace/oneagent/manifest.json ] ; then
    if [ -f /opt/dynatrace/oneagent/dynatrace-env.sh ]; then
      log "Agent already exists." WARN
    else
      log "Instrument container using Dynatrace agent template"
      start_using_agent_template
    fi
  else
    log "Download and install Dynatrace agent"
    download_and_install_agent
  fi
}


case "$1" in
"prepare")  log "Setting up Dynatrace paas agent for beeing shipped"
    prepare
    ;;
"start")  log "Setting up Dynatrace paas agent for start"
    start
    ;;
*) echo "Invalid parameter, use:
prepare - will prepare a paas agent to be shipped
start - will setup secrets into agent so that it can connect to an environment

Required environment variables are: DT_API_TOKEN, DT_API_URL, DT_TENANT
Optional environment variables are: DT_SKIP_ERRORS, DT_APPLICATION_ID, DT_HOST_ID
"
   exit 1
   ;;
esac


