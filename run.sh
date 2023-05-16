#!/bin/bash

TEST_DB="test_IMIS"
VALID_DATABASES="pgsql,mssql"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

function usage() {
  echo """
  Runs command and tools in a containerized environment for the development of
  the backend.

  $0 COMMAND [parameters]

  COMMANDS:

  bootstrap       bootstraps the development environment.
  db  [name]      sets and uses the database type (restart if running) or gets
                  it if nothing passed.
                  possible values: ${VALID_DATABASES}
  default [name]  sets the default service to interact with (shell) or gets it
                  if nothing passed.
  disable <name>  disables a given service (backend and db can't be disabled).
  enable  <name>  enables a given service (db and backend are mandatory).
                  possible values: $(available_services | tr '\r\n' ',' | sed "s/.$//")
  enabled         lists enabled services.
  logs <name>     prints the logs for the given service.
  prepare_db      prepares the database (required before running test in backend)
  refresh <name>  refreshes a service by rebuilding its image and (re)starting
                  it.
  server          runs the backend server in background.
  shutdown        stops the backend server.
  settings        reads current settings if any.
  shell [name]    runs an interactive shell on the given service or the default
                  one if nothing passed.
  status          returns current status of the environment.
  stop            stops the environment if running.
  test            runs test for given module in backend.
  warmup          warms up enabled services.
  workon <name>   switches a module in backend for its local version for
                  development.
  """
}

SETTINGS_FILE="${SCRIPT_DIR}/openimis-dev.json"
IFS='' read -r -d '' SETTINGS_DEFAULT <<'EOF'
{
    "default": "backend",
    "services": "db,backend",
    "db": "pgsql"
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
  cd "${SCRIPT_DIR}/modules/${sub_directory}" || {
    echo "The directory \`modules\` is unexpectedly absent. It should not happend as it is part of the present project."
    exit 1
  }
}

function cd_openimis-dist_dkr() {
  cd "${SCRIPT_DIR}/openimis-dist_dkr" || {
    echo "The directory \`openimis-dist_dkr\` is unexpectedly absent. This probably means the cloning of the Git repository \`https://github.com/openimis/openimis-dist_dkr\` has failed."
    exit 1
  }
}

function docker-compose-command() {
  # relative to openimis-dist_dkr directory
  echo -n "docker compose "
  if [[ $(get_database) == "mssql" ]]; then
    echo -n "-f docker-compose-mssql.yml "
  else
    echo -n "-f docker-compose.yml "
  fi
  echo -n "-f ../docker-compose.yml.local-dev "
  if [[ $(get_database) == "mssql" ]]; then
    echo "-f ../docker-compose-mssql.yml.local-dev"
  else
    echo "-f ../docker-compose-pgsql.yml.local-dev "
  fi
}

function dckr-compose() {
  (
    cd_openimis-dist_dkr
    $(docker-compose-command) "$@"
  )
}

function warmup() {
  echo "Warming up services $(get_enabled_services) if not running"
  # shellcheck disable=SC2046
  dckr-compose up -d $(get_enabled_services | tr ',' ' ')
  echo "---------------------------------------------------"
}

function service_status() {
  local service=$1
  if is_running "${service}"; then
    echo "OK"
  else
    echo "KO"
  fi
}

function backend_status() {
  if is_running "backend"; then
    if dckr-compose exec backend pgrep -f "python server.py" >/dev/null; then
      echo "OK"
    else
      echo "KO"
    fi
  else
    echo "KO"
  fi
}

function running_disabled_services() {
  running_services | tr '\r\n' ' ' | sed -e "s/\($(get_enabled_services | sed -e "s/,/\\\|/g")\)//g" -e "s/^[[:space:]]\+//" -e "s/[[:space:]]\+$//" -e "s/[[:space:]]\+/ /"
}

function status() {
  # boostrapped status
  # config
  echo "Services:"
  for service in $(get_enabled_services | tr ',' ' '); do
    echo "  ${service}: $(service_status "${service}")"
  done
  echo "  backend server: $(backend_status)"
  for service in $(running_disabled_services); do
    echo "  ${service} (disabled): OK"
  done
}

function refresh() {
  local service=$1
  check_service "${service}" || {
    echo "The service \`${service}\` does not exist. Please select one of the"
    echo "following:"
    available_services | tr '\n\r' ' '
    exit 1
  }

  if is_running "${service}"; then
    dckr-compose build "${service}"
    dckr-compose restart "${service}"
  else
    dckr-compose up --build -d "${service}"
  fi
  # echo "Refreshing running and enabled services $(get_enabled_services)"
  # # shellcheck disable=SC2046
  # dckr-compose restart $(get_enabled_services | tr ',' ' ')
  # echo "---------------------------------------------------"
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

function check_database() {
  local database=$1
  contains "${VALID_DATABASES}" "${database}"
}

function check_service() {
  local service=$1
  contains "$(available_services)" "${service}"
}

function running_services() {
  dckr-compose ps --services --all --filter status=running | tr '\r\n' ' '
}

function is_running() {
  local service=$1
  contains "$(running_services)" "${service}"
}

function get_default_service() {
  get_setting "default"
}

function get_enabled_services() {
  get_setting "services"
}

function get_database() {
  get_setting "db"
}

function set_dotenv() {
  sed -i -e "s/^RESTAPI_BRANCH=.*$/RESTAPI_BRANCH=fix\/use_archive_debian/" -e "s/^DB_BRANCH=.*$/DB_BRANCH=develop/" "${SCRIPT_DIR}/openimis-dist_dkr/.env"
  if [[ $(get_database) == "mssql" ]]; then
    sed -i -e "s/^#ACCEPT_EULA.*$/ACCEPT_EULA=y/" -e "s/^DB_PORT=.*$/DB_PORT=1433/" -e "s/^DB_ENGINE=.*$/DB_ENGINE=mssql/" "${SCRIPT_DIR}/openimis-dist_dkr/.env"
  else
    sed -i -e "s/^.*ACCEPT_EULA.*$/#ACCEPT_EULA=n/" -e "s/^DB_PORT=.*$/DB_PORT=5432/" -e "s/^DB_ENGINE=.*$/DB_ENGINE=django.db.backends.postgresql/" "${SCRIPT_DIR}/openimis-dist_dkr/.env"
  fi
}

function contains() {
  local string=$1
  local substring=$2
  echo "${string}" | grep -qw "${substring}"
}

function download_mssql_scripts() {
  [[ -d "${SCRIPT_DIR}/database_ms_sqlserver" ]] ||
    git clone https://github.com/openimis/database_ms_sqlserver.git "${SCRIPT_DIR}/database_ms_sqlserver/"
  (
    cd "${SCRIPT_DIR}/database_ms_sqlserver/" || {
      echo "The directory \`database_ms_sqlserver\` is unexpectedly absent. This probably means the cloning of the Git repository \`https://github.com/openimis/database_ms_sqlserver\` has failed."
      exit 1
    }
    git checkout develop
    bash ./concatenate_files.sh
  )
  (
    cd "${SCRIPT_DIR}/openimis-dist_dkr" || {
      echo "The directory \`openimis-dist_dkr\` is unexpectedly absent. This probably means the cloning of the Git repository \`https://github.com/openimis/openimis-dist_dkr\` has failed."
      exit 1
    }
    [[ -L database_ms_sqlserver ]] || ln -fs ../database_ms_sqlserver .

  )
}

case "$1" in
"bootstrap")
  echo "Boostrapping the dev environment"
  echo
  echo "Cloning OpenIMIS Backend Python and Distribution Docker"
  [[ -d "${SCRIPT_DIR}/openimis-be_py" ]] || git clone git@github.com:openimis/openimis-be_py.git "${SCRIPT_DIR}/openimis-be_py"
  [[ -d "${SCRIPT_DIR}/openimis-dist_dkr" ]] || git clone https://github.com/openimis/openimis-dist_dkr "${SCRIPT_DIR}/openimis-dist_dkr"

  echo
  echo "Linking local directory to be bound in Docker container"
  (
    cd "${SCRIPT_DIR}/openimis-dist_dkr" || {
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

  echo
  echo "Generating dotenv file"
  sed -e "s/^#\(OPENIMIS_.*=\).*$/\1\"\"/g" -e "/^#.*$/ d" -e "/^[[:space:]]*$/d" -e "/^DB_ENGINE/a #ACCEPT_EULA=" <"${SCRIPT_DIR}/openimis-dist_dkr/.env.example" >"${SCRIPT_DIR}/openimis-dist_dkr/.env"
  set_dotenv
  ;;

"status")
  status
  ;;

"logs")
  service_to_log=${2:-$(get_default_service)}
  dckr-compose logs ${follow_option} "$service_to_log"
  ;;

"refresh")
  refresh "$2"
  ;;

"shell")
  service_to_interact_with=${2:-$(get_default_service)}
  warmup
  echo "Entering interactive shell:"
  dckr-compose exec -ti "${service_to_interact_with}" bash
  ;;

"prepare_db")
  echo -n "Downloading SQL scripts ... "
  download_mssql_scripts
  echo "OK"
  warmup
  echo "Preparing db"
  case "$(get_database)" in
  "pgsql")
    # That might need also updated scripts as mssql, to check
    dckr-compose exec db bash -c \
      "PGPASSWORD=\$POSTGRES_PASSWORD psql -h \$HOSTNAME -U \$POSTGRES_USER \$POSTGRES_DB -c \"DROP DATABASE IF EXISTS \\\"$TEST_DB\\\"\" -c \"CREATE DATABASE \\\"$TEST_DB\\\"\" -c \"DROP ROLE \\\"postgres\\\"\" -c \"CREATE ROLE \\\"postgres\\\" WITH SUPERUSER\""
    ;;
  "mssql")
    dckr-compose exec db bash -c \
      "/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P \$SA_PASSWORD -Q \"DROP DATABASE IF EXISTS $TEST_DB; CREATE DATABASE $TEST_DB;\"; /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P \$SA_PASSWORD -d $TEST_DB -Q \"EXEC sp_changedbowner '\$DB_USER'\"; /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P \$SA_PASSWORD -d master -Q \"GRANT CREATE ANY DATABASE TO \$DB_USER\";"
    dckr-compose exec db bash -c \
      "/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P \$SA_PASSWORD -Q \"DROP DATABASE IF EXISTS \$DB_NAME; CREATE DATABASE \$DB_NAME;\"; /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P \$SA_PASSWORD -Q \"USE \$DB_NAME; EXEC sp_changedbowner '\$DB_USER'\"; /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P \$SA_PASSWORD -i /database_ms_sqlserver/output/fullDemoDatabase.sql -d \$DB_NAME | grep . | uniq -c"
    ;;
  esac
  dckr-compose exec backend bash -c "PATH=\${PATH}:/opt/mssql-tools/bin/ python init_test_db.py | grep . | uniq -c"
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
  echo "Database: $(get_database)"
  ;;

"db")
  database=$2
  [[ -z $database ]] && {
    echo "Database is: $(get_database)"
    exit 0
  }
  check_database "${database}" || {
    echo "The database \`${database}\` is not valid. Please select one of the"
    echo "following:"
    echo "${VALID_DATABASES/,/ }"
    exit 1
  }
  [[ $(get_database) == "${database}" ]] && {
    echo "The database is already \`${database}\`."
    exit 0
  }
  [[ $database == "pgsql" ]] && contains "$(get_enabled_services)" "restapi" && {
    echo "restapi does not work with database PostgreSQL. Please disable the"
    echo "service first with:"
    echo "$0 disable restapi"
    exit 1
  }
  is_running "db"
  restart_needed=$?
  [[ $restart_needed -eq 0 ]] && {
    echo -n "Stopping all services ... "
    dckr-compose down
    echo "OK"
  }
  echo -n "Setting database to \`${database}\` ... "
  save_settings "$(set_settings "{\"db\": \"${database}\"}")"
  set_dotenv
  echo "OK"
  [[ $restart_needed -eq 0 ]] && warmup
  ;;

"default")
  default_service=$2
  [[ -z $default_service ]] && {
    echo "Default service is: $(get_default_service)"
    exit 0
  }
  check_service "${default_service}" || {
    echo "The service \`${default_service}\` does not exist. Please select one of the"
    echo "following:"
    available_services | tr '\n\r' ' '
    exit 1
  }
  contains "$(get_enabled_services)" "${default_service}" || {
    echo "The service \`${default_service}\` is not enabled. Please select one of the"
    echo "following:"
    get_enabled_services
    exit 1
  }

  echo -n "Setting default service to \`${default_service}\` ... "
  save_settings "$(set_settings "{\"default\": \"${default_service}\"}")"
  echo "OK"
  ;;

"enabled")
  get_enabled_services
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
  if contains "${enabled_services}" "$service_to_enable"; then
    echo "The service \`${service_to_enable}\` is already enabled."
    exit 0
  else
    [[ $(get_database) == "pgsql" ]] && [[ $service_to_enable == "restapi" ]] && {
      echo "${service_to_enable} does not work with database PostgreSQL. Please switch"
      echo "to the database Microsoft SQL Server first with:"
      echo "$0 db mssql"
      exit 1
    }
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
    contains "${service_to_disable}" "${mandatory_service}" && {
      echo "The service \`${service_to_disable}\` is a mandatory service."
      echo "You cannot disable it."
      exit 1
    }
  done

  if contains "${enabled_services}" "${service_to_disable}"; then
    echo -n "Disabling service \`${service_to_disable}\` ... "
    enabled_services="$(echo "${enabled_services}" | sed -e "s/\,/\\n/g" | sed "/${service_to_disable}/d" | sort | uniq | tr '\n' ',' | sed 's/.$//')"
    save_settings "$(set_settings "{\"services\": \"${enabled_services}\"}")"
    echo "OK"
  else
    echo "The service \`${service_to_disable}\` is already disabled."
    exit 0
  fi

  if [[ $(get_default_service) == "${service_to_disable}" ]]; then
    echo "Service \`${service_to_disable}\` is the current default."
    echo -n "Setting default service to \`backend\` ... "
    save_settings "$(set_settings "{\"default\": \"backend\"}")"
    echo "OK"
  fi
  ;;

"server")
  warmup
  echo -n "Starting backend server in the background ..."
  dckr-compose exec -d backend bash -c "/openimis-be/script/entrypoint.sh start > /proc/1/fd/1"
  echo "OK"
  ;;

"shutdown")
  echo -n "Shutting down backend server ..."
  dckr-compose exec backend bash -c "echo -n 'Stopping Django ...' > /proc/1/fd/1; pkill -SIGINT -f 'python server.py'; echo 'OK' > /proc/1/fd/1;"
  ;;

"warmup")
  echo "Warming up all enabled services ..."
  warmup
  ;;

*)
  usage
  ;;

esac
