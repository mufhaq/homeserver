#!/bin/bash

FILE_ENV=""
FILE_ENV_DEFAULT=".env"
FILE_ENV_EXAMPLE="$FILE_ENV.example"
FILE_ENV_LOCAL=""
FILE_ENV_LOCAL_FLAG=""
FILE_ENV_LOCAL_SCAN=""
declare -i FILE_ENV_TEST_ENABLED

DOCKER_COMMAND_COMPOSE="docker compose"
DOCKER_DIR="$(pwd)"
DOCKER_DIR_APPS=${DOCKER_DIR_APPS:-"$DOCKER_DIR/src/main"}
DOCKER_DIR_APPS_TEST=${DOCKER_DIR_APPS_TEST:-"$DOCKER_DIR/src/test"}
DOCKER_DIR_VOLUME=${DOCKER_DIR_VOLUME:-"$DOCKER_DIR/volume/main"}
DOCKER_DIR_VOLUME_TEST=${DOCKER_DIR_VOLUME_TEST:-"$DOCKER_DIR/volume/test"}
DOCKER_DIR_APP_SUB=""
DOCKER_FILE_NAME_COMPOSE="docker-compose.yml"
DOCKER_FILE_CONFIG=${DOCKER_FILE_CONFIG:-"$DOCKER_DIR_APPS/config/$DOCKER_FILE_NAME_COMPOSE"}
DOCKER_COMMAND_LIST="up up-test down down-test"
DOCKER_COMMAND_ACTION=""
DOCKER_COMMAND_ACTION_FLAG=""
DOCKER_FILE_LIST=""
DOCKER_FILE_LIST_FLAG=""
declare GLOBAL_RETURN

DOCKER_COMMAND_DETACH=1
DOCKER_COMMAND_UP_TEST=0
DOCKER_MESSAGE_ENABLE=1

export DOCKER_DIR
export DOCKER_DIR_APPS
export DOCKER_DIR_VOLUME

function get_global_return_int() {
  return $GLOBAL_RETURN
}

# use this in conjunction with echo '<string>' if want get return value but in string
# example function return string: result=$(some_function "some args for echo")
function get_global_return_str() {
  echo $GLOBAL_RETURN
}

function add_message() {
  message=""
  if [ $1 -eq 0 ]; then
    message="$2"
    if [ ! -z "$4" ] && [ "$4" != 0 ]; then
      message+=", $4"
    fi
  else
    message="$3"
    if [ ! -z "$5" ] && [ "$5" != 0 ]; then
      message+=", $5"
    fi
  fi
  if [ $DOCKER_MESSAGE_ENABLE -eq 1 ]; then
    echo $message
  fi
}

function check_app_from_list() {
  result=1
  for app in $DOCKER_APP_LIST; do
    if [ "$app" = "$1" ]; then
      result=0
      break
    fi
  done
  add_message $result "[$1] docker app found" "[$1] docker app not found" "$2" "$3"
  GLOBAL_RETURN=$result
}

function check_file() {
  result=1
  if [ -f "$2" ]; then
    result=0
  fi
  add_message $result "[$1] $2 found" "[$1] $2 not found" "$3" "$4"
  GLOBAL_RETURN=$result
}

function check_app_compose() {
  docker_file_compose="$DOCKER_DIR_APPS/$1/$DOCKER_FILE_NAME_COMPOSE"
  check_file "$1" "$docker_file_compose"
  if ! get_global_return_int; then
    GLOBAL_RETURN=1
    return
  fi
  GLOBAL_RETURN=0
}

function check_app_config() {
  check_app_compose "config"
  if ! get_global_return_int; then
    exit 1
  fi
  DOCKER_FILE_CONFIG="$DOCKER_DIR_APPS/config/$DOCKER_FILE_NAME_COMPOSE"
}

function check_dir() {
  result=1
  if [ -d "$2" ]; then
    result=0
  fi
  add_message $result "[$1] $2 directory found" "[$1] $2 directory not found" "$3" "$4"
  GLOBAL_RETURN=$result
}

function check_dir_app() {
  check_dir "$1" "$DOCKER_DIR_APPS/$1"
}

function check_dir_app_content() {
  app_dir="$DOCKER_DIR_APPS/$1"
  result=1
  if find "$app_dir" -mindepth 1 -maxdepth 1 | read; then
    result=0
  fi
  add_message $result "[$1] $app_dir directory content found" "[$1] $app_dir directory is empty" "$2" "$3"
  GLOBAL_RETURN=$result
}

function get_dir_app_subdirectories() {
  DOCKER_DIR_APP_SUB=""
  index=0
  for subdirectory_full_path in "$DOCKER_DIR_APPS/$1"/*/; do
    subdirectory_full_path=${subdirectory_full_path%/} # strip trailing slash
    subdirectory_app_name="$1/$(basename $subdirectory_full_path)"
    add_message 0 "[$1] $subdirectory_full_path subdirectory found"
    if [ $index -gt 0 ]; then
      DOCKER_DIR_APP_SUB+=" "
    fi
    DOCKER_DIR_APP_SUB+="$subdirectory_app_name"
    index=$((index+1))
  done
}

function scan_env_local() {
  FILE_ENV_LOCAL_SCAN=""
  for file_env in $(find "$DOCKER_DIR_APPS/$1" -type f ! -name "*example*" -type f -name "*env*"); do
    check_file "$1" "$file_env"
    if [ ! -z "$FILE_ENV_LOCAL_SCAN" ]; then
      FILE_ENV_LOCAL_SCAN+=" "
    fi
    FILE_ENV_LOCAL_SCAN+="$file_env"
  done
  if [ -z "$FILE_ENV_LOCAL_SCAN" ]; then
    GLOBAL_RETURN=1
  else
    GLOBAL_RETURN=0
  fi
}

function get_env_local() {
  dir_env_basename=$(basename "$1")
  for file_env in $FILE_ENV_LOCAL_SCAN; do
    file_env_dirname=$(basename $(dirname $file_env))
    if [ "$file_env_dirname" = "$dir_env_basename" ]; then
      get_exported_env "$file_env"
      if [ ! -z "$FILE_ENV_LOCAL" ]; then
        FILE_ENV_LOCAL+=" "
      fi
      FILE_ENV_LOCAL+="$file_env"
    fi
  done
}

declare -i check_found_compose
declare -i check_found_app_sub
declare -i check_app_list=1
function check_app() {
  check_found_compose=1
  check_found_app_sub=1
  if [ $check_app_list -eq 1 ]; then
    check_app_from_list $1
    if ! get_global_return_int; then
      GLOBAL_RETURN=1
      return
    fi
  fi
  check_dir_app $1
  if ! get_global_return_int; then
    GLOBAL_RETURN=1
    return
  fi
  check_app_compose $1
  if ! get_global_return_int; then
    check_found_compose=0
    check_dir_app_content $1
    if [ $check_found_compose -eq 0 ] && ! get_global_return_int; then
      check_found_app_sub=0
      GLOBAL_RETURN=1
      return
    fi
  fi
  GLOBAL_RETURN=0
  return
}

function get_app() {
  check_app $1
  if ! get_global_return_int; then
    GLOBAL_RETURN=1
    return
  fi
  scan_env_local $1
  if get_global_return_int; then
    get_env_local $1
  fi
  if [ $check_found_compose -eq 0 ] && [ $check_found_app_sub -eq 1 ]; then
    get_dir_app_subdirectories $1
    get_apps "$DOCKER_DIR_APP_SUB"
  else
    if [ ! -z "$DOCKER_FILE_LIST" ]; then
      DOCKER_FILE_LIST+=" "
    fi
    DOCKER_FILE_LIST+="$DOCKER_DIR_APPS/$1/$DOCKER_FILE_NAME_COMPOSE"
  fi
  GLOBAL_RETURN=0
  return
}

function get_apps() {
  app_list=${1:-$DOCKER_APP_LIST}
  if [ "$app_list" != "$DOCKER_APP_LIST" ]; then
    check_app_list=0
  else
    check_app_list=1
  fi
  for app in $app_list; do
    get_app "$app"
  done
}

function get_app_list() {
  if [ ! -z "$1" ]; then
    get_app $1
  else
    get_apps
  fi
}

function use_dir_app_test() {
  check_dir "apps_test" "$DOCKER_DIR_APPS_TEST" 0 "please create folder $DOCKER_DIR_APPS_TEST"
  if ! get_global_return_int; then
    exit 1
  fi
  DOCKER_DIR_APPS="$DOCKER_DIR_APPS_TEST"
  DOCKER_DIR_VOLUME="$DOCKER_DIR_VOLUME_TEST"
}

function check_env() {
  declare -i file_found=0
  FILE_ENV="$FILE_ENV_DEFAULT"
  if [ $DOCKER_COMMAND_UP_TEST -eq 1 ]; then
    FILE_ENV=".test.env"
    use_dir_app_test
  fi
  if [ ! -f $FILE_ENV ]; then
    echo "Please add $FILE_ENV file"
    GLOBAL_RETURN=1
    return
  else
    file_found=1
  fi
  if [ $file_found -eq 0 ]; then
    if [ ! -f $FILE_ENV_EXAMPLE ]; then
      echo "Please rename file .env.example to $FILE_ENV"
      GLOBAL_RETURN=1
      return
    fi
  fi
  GLOBAL_RETURN=0
  return
}

# https://gist.github.com/mihow/9c7f559807069a03e302605691f85572?permalink_comment_id=4223773#gistcomment-4223773
function get_exported_env() {
  #echo "found .env"
  while read -r LINE; do
    if [[ $LINE == *'export'* ]]; then
      ENV_VAR="$(echo $LINE | envsubst)"
      eval "readonly $ENV_VAR"
    fi
  done < $1
}

function get_action() {
  if [ -z "$1" ]; then
    echo "Please use one command \"up\" or \"down\""
    exit 1
  fi
  declare -i command_found=0
  for command in $DOCKER_COMMAND_LIST; do
    if [ $1 = "$command" ]; then
      command_found=1
    fi
  done
  if [ $command_found -eq 1 ]; then
    if [ "$1" = "up" ] || [ "$1" = "up-test" ] && [ $DOCKER_COMMAND_DETACH -eq 1 ]; then
      DOCKER_COMMAND_ACTION+="up"
      DOCKER_COMMAND_ACTION_FLAG+="-d"
    else
      DOCKER_COMMAND_ACTION+="down"
    fi
    if [ "$1" = "up-test" ] || [ "$1" = "down-test" ]; then
      DOCKER_COMMAND_UP_TEST=1
    fi
    return 0
  fi
  echo "Command not found, please use one command \"up\" or \"down\""
  exit 1
}

function set_app_flag() {
  index=0
  for file in $DOCKER_FILE_LIST; do
    if [ $index -gt 0 ]; then
      DOCKER_FILE_LIST_FLAG+=" "
    fi
    DOCKER_FILE_LIST_FLAG+="-f $file"
    index=$((index+1))
  done
}

function set_env() {
  file_env_config="$DOCKER_DIR_APPS/config/$FILE_ENV"
  cat $FILE_ENV > $file_env_config
  if [ ! -z "$FILE_ENV_LOCAL" ]; then
    for file_env in $FILE_ENV_LOCAL; do
      cat $file_env >> $file_env_config
    done
  fi
}

function set_command() {
  DOCKER_COMMAND+="$DOCKER_COMMAND_COMPOSE --env-file=$DOCKER_DIR_APPS/config/$FILE_ENV -f $DOCKER_FILE_CONFIG $DOCKER_FILE_LIST_FLAG $DOCKER_COMMAND_ACTION $DOCKER_COMMAND_ACTION_FLAG"
}

function execute() {
  get_action $1
  check_env
  if ! get_global_return_int; then
    exit 1
  fi
  get_exported_env $FILE_ENV
  check_app_config
  get_app_list $2
  set_app_flag
  set_env
  set_command
  eval "$DOCKER_COMMAND"
  if [ "$DOCKER_COMMAND_ACTION" = "down" ]; then
    :> $DOCKER_DIR_APPS/config/$FILE_ENV # remove all environment variables
    return
  fi
}

function compose() {
  execute $1 $2
}

compose $1 $2
