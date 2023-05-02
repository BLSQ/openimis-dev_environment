#!/bin/bash

DOCKER_COMPOSE_COMMAND="docker compose -f docker-compose.yml -f ../docker-compose.yml.local-dev"
TEST_DB="test_IMIS"

function usage() {
  echo """
  Runs command and tools in a containerized environment for the development of
  the backend.

  bootstrap     bootstraps the development environment
  default       sets the default service to interact with (shell)
  disable       disables a given service (backend and db can't be disabled)
  enable        enables a given service (by default db and backend are run)
  prepare_test  prepares the test environment in backend, in particular the database    
  server        runs the backend server
  settings      reads current settings if any
  shell         runs an interactive shell on the default service
  status        returns current status of the environment
  stop          stops the environment if running
  test          runs test for given module in backend
  workon        switches a module in backend for its local version for development
  """
}

SETTINGS_FILE="openimis-dev.json"
IFS='' read -r -d '' SETTINGS_DEFAULT <<'EOF'
{
    "default": "backend",
    "services": "db,backend"
}
EOF

function load_settings() {
  if [[ -r $SETTINGS_FILE ]]; then
    echo "${SETTINGS_DEFAULT}$(cat "${SETTINGS_FILE}")" | jq '. * input'
  else
    echo "${SETTINGS_DEFAULT}"
  fi
}

function save_settings() {
  local settings=$1

  [[ ! -w $SETTINGS_FILE ]] && {
    echo "The settings file \`${SETTINGS_FILE}\` is not writable. Its current permission is"
    echo "\`$(stat -c'%A %U %G' "${SETTINGS_FILE}")\`. If you have the rights, you can make it"
    echo "writeble with \`chmod u+w\`."
    exit 1
  }
  echo "${settings}" >"${SETTINGS_FILE}"
}

function cd_modules() {
  local sub_directory=$1
  cd "modules/${sub_directory}" || {
    echo "The directory \`modules\` is unexpectedly absent. It should not happend as it is part of the present project."
    exit 1
  }
}

function cd_openimis-dist_dkr() {
  cd openimis-dist_dkr || {
    echo "The directory \`openimis-dist_dkr\` is unexpectedly absent. This probably means the cloning of the Git repository \`https://github.com/openimis/openimis-dist_dkr\` has failed."
    exit 1
  }
}

function dckr-compose() {
  (
    cd_openimis-dist_dkr
    $DOCKER_COMPOSE_COMMAND "$@"
  )
}

function warmup() {
  echo "Warming up services $(get_enabled_services) if not running"
  dckr-compose up -d $(get_enabled_services | tr ',' ' ')
  echo "---------------------------------------------------"
}

function get_uri_from_git_repo() {
  local module_repo=$1

  echo "${module_repo}" | cut -d@ -f1
}

function get_name_from_git_repo() {
  local module_repo=$1
  get_uri_from_git_repo "${module_repo}" | sed -e "s/.\+\/\(.\+\)\.git/\1/"
}

function clone_module() {
  local module_name, module_repo, module_repo_uri, module_repo_branch, module_repo_name
  module_name=$1
  module_repo=$2
  module_repo_uri="$(get_uri_from_git_repo "${module_repo}")"
  module_repo_branch="$(echo "${module_repo}" | cut -d@ -f2)"
  module_repo_name="$(get_name_from_git_repo "${module_repo}")"

  [[ -z $module_repo_name ]] && (
    echo "We couldn't find the name of the module from the Git repo URI:"
    echo "${module_name}: ${module_repo}"
    echo "The URI should be of the following form \`https://domain/path/reponame.git[@branchname]\`."
    echo "If it is not the case, please check its format in \`openimis.json\`,"
    echo "it is formatted as a remote Git repo for pip:"
    echo "\`git+https://domain/path/reponame.git[@branchname][#pipoption].\`"
    exit 1
  )

  [[ ! -d modules/$module_repo_name ]] && (
    cd_modules
    git clone "${module_repo_uri}" "${module_repo_name}"
  )
  [[ -n $module_repo_branch ]] && (
    cd_modules "${module_repo_name}"
    git checkout "${module_repo_branch}"
  )
  (
    cd_modules "${module_repo_name}"
    git pull
  )
}

function known_module() {
  local module_name=$1
  module_repo="$(jq --arg var "$module_name" -r '(.modules[] | select(any(.==$var))) | .pip' ./openimis-be_py/openimis.json)"
  [[ -n $module_repo ]]
}

function get_module_repo() {
  local module_name=$1
  module_repo="$(jq --arg var "$module_name" -r '(.modules[] | select(any(.==$var))) | .pip' ./openimis-be_py/openimis.json | sed -e "s/git+\(.\+\)#.\+/\1/")"
  [[ -z $module_repo ]] && {
    echo "The module $2 is unknown."
    exit 1
  }
  echo "${module_repo}"
}

function set_settings() {
  local new_settings=$1

  echo "$(load_settings)${new_settings}" | jq '. * input'
}

function get_setting() {
  local property=$1
  load_settings | jq -r ".${property}"
}

function available_services() {
  dckr-compose config --services
}

function check_service() {
  local service=$1
  available_services | grep -qw "${service}"
}

function get_default_service() {
  get_setting "default"
}

function get_enabled_services() {
  get_setting "services"
}

case "$1" in
"bootstrap")
  echo "Boostrapping the dev environment"
  echo
  echo "Cloning OpenIMIS Backend Python and Distribution Docker"
  [[ -d openimis-be_py ]] || git clone git@github.com:openimis/openimis-be_py.git openimis-be_py
  [[ -d openimis-dist_dkr ]] || git clone https://github.com/openimis/openimis-dist_dkr openimis-dist_dkr

  echo
  echo "Linking local directory to be bound in Docker container"
  (
    cd openimis-dist_dkr || {
      echo "The directory \`openimis-dist_dkr\` is unexpectedly absent. This probably means the cloning of the Git repository \`https://github.com/openimis/openimis-dist_dkr\` has failed."
      exit 1
    }
    [[ -L openimis-be_py ]] || ln -fs ../openimis-be_py .
    [[ -L modules ]] || ln -fs ../modules .
  )

  echo
  echo "Generating Dockerfile to customized backend Docker image"
  sed -e "s/\(FROM python:3.8-buster\)/\1 AS ORIGIN/" ./openimis-be_py/Dockerfile >Dockerfile
  cat Dockerfile.override >>Dockerfile
  ;;

"ps")
  dckr-compose ps
  ;;

"shell")
  warmup
  echo "Entering interactive shell:"
  dckr-compose exec -ti "$(get_default_service)" bash
  ;;

"prepare_test")
  warmup
  echo "Preparing test"
  dckr-compose exec db bash -c \
    "PGPASSWORD=\$POSTGRES_PASSWORD psql -h \$HOSTNAME -U \$POSTGRES_USER \$POSTGRES_DB -c \"DROP DATABASE IF EXISTS \\\"$TEST_DB\\\"\" -c \"CREATE DATABASE \\\"$TEST_DB\\\"\" -c \"DROP ROLE \\\"postgres\\\"\" -c \"CREATE ROLE \\\"postgres\\\" WITH SUPERUSER\""
  dckr-compose exec backend bash -c "python init_test_db.py | grep . | uniq -c"
  ;;

"test")
  module_name=$2
  known_module "${module_name}" || (
    echo "The module $2 is unknown."
    exit 1
  )
  warmup
  echo "Running test for module ${module_name}"
  dckr-compose exec backend bash -c "python manage.py test --keepdb $module_name"
  ;;

"workon")
  module_name=$2
  module_repo=$(get_module_repo "${module_name}")
  echo "Cloning ${module_name} from ${module_repo}"
  clone_module "${module_name}" "${module_repo}"
  module_repo_name=$(get_name_from_git_repo "${module_repo}")
  echo "Switching from remote version to local version for ${module_name}"
  echo "From ${module_repo} to ./modules/${module_repo_name}"

  warmup
  dckr-compose exec backend bash -c "pip uninstall -y openimis-be-${module_name}"
  dckr-compose exec backend bash -c "pip install -e ../../modules/${module_repo_name}/"
  ;;

"stop")
  echo "Stopping everything"
  dckr-compose down
  ;;

"settings")
  echo "Default service: $(get_default_service)"
  echo "Enabled services: $(get_enabled_services)"
  ;;

"default")
  default_service=$2
  check_service "${default_service}" || {
    echo "The service \`${default_service}\` does not exist. Please select one of the"
    echo "following:"
    available_services | tr '\n\r' ' '
    exit 1
  }
  echo -n "Setting default service to \`${default_service}\` ... "
  save_settings "$(set_settings "{\"default\": \"${default_service}\"}")"
  echo "OK"
  ;;

"enable")
  service_to_enable=$2
  check_service "${service_to_enable}" || {
    echo "The service \`${service_to_enable}\` does not exist. Please select one of the"
    echo "following:"
    available_services | tr '\n\r' ' '
    exit 1
  }
  enabled_services="$(get_setting "services")"
  if echo "${enabled_services}" | grep -qw "$service_to_enable"; then
    echo "The service \`${service_to_enable}\` is already enabled."
    exit 0
  else
    echo -n "Enabling service \`${service_to_enable}\` ... "
    enabled_services="$(echo "${enabled_services},${service_to_enable}" | sed -e "s/\,/\\n/g" | sort | uniq | tr '\n' ',' | sed 's/.$//')"
    save_settings "$(set_settings "{\"services\": \"${enabled_services}\"}")"
    echo "OK"
  fi
  ;;

"disable")
  service_to_disable=$2
  check_service "${service_to_disable}" || {
    echo "The service \`${service_to_disable}\` does not exist. Please select one of the"
    echo "following:"
    available_services | tr '\n\r' ' '
    exit 1
  }
  enabled_services="$(get_setting "services")"
  mandatory_services="backend db"
  for mandatory_service in $mandatory_services; do
    echo "${service_to_disable}" | grep -qw "${mandatory_service}" && {
      echo "The service \`${service_to_disable}\` is a mandatory service."
      echo "You cannot disable it."
      exit 1
    }
  done

  if echo "${enabled_services}" | grep -qw "${service_to_disable}"; then
    echo -n "Disabling service \`${service_to_disable}\` ... "
    enabled_services="$(echo "${enabled_services}" | sed -e "s/\,/\\n/g" | sed "/${service_to_disable}/d" | sort | uniq | tr '\n' ',' | sed 's/.$//')"
    save_settings "$(set_settings "{\"services\": \"${enabled_services}\"}")"
    echo "OK"
  else
    echo "The service \`${service_to_disable}\` is already disabled."
    exit 0
  fi
  ;;

*)
  usage
  ;;

esac
