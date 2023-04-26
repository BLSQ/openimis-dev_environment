#!/bin/bash

DOCKER_COMPOSE_COMMAND="docker compose -f docker-compose.yml -f ../docker-compose.yml.local-dev"
TEST_DB="test_IMIS"

function usage() {
  echo """
  Runs command and tools in a containerized environment for the development of
  the backend.

  bootstrap     bootstraps the development environment
  prepare_test  prepares the test environment, in particular the database    
  server        runs the backend server
  shell         runs an interactive shell
  status        returns current status of the environment
  stop          stops the environment if running
  test          runs test for given module
  workon        switches a module for its local version for development
  """
}

function dckr-compose() {
  (
    cd openimis-dist_dkr
    $DOCKER_COMPOSE_COMMAND "$@"
  )
}

function warmup() {
  echo "Warming up DB and Backend if not running"
  dckr-compose up -d backend
  echo "---------------------------------------------------"
}

function get_uri_from_git_repo() {
  local module_repo=$1

  echo $module_repo | cut -d@ -f1
}

function get_name_from_git_repo() {
  local module_repo=$1
  get_uri_from_git_repo $module_repo | sed -e "s/.\+\/\(.\+\)\.git/\1/"
}

function clone_module() {
  local module_name=$1
  local module_repo=$2
  local module_repo_uri="$(get_uri_from_git_repo $module_repo)"
  local module_repo_branch="$(echo $module_repo | cut -d@ -f2)"
  local module_repo_name="$(get_name_from_git_repo $module_repo)"

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
    cd modules
    git clone $module_repo_uri $module_repo_name
  )
  [[ ! -z $module_repo_branch ]] && (
    cd modules/$module_repo_name
    git checkout $module_repo_branch
  )
  (
    cd modules/$module_repo_name
    git pull
  )
}

function known_module() {
  local module_name=$1
  module_repo="$(jq --arg var "$module_name" -r '(.modules[] | select(any(.==$var))) | .pip' ./openimis-be_py/openimis.json)"
  [[ ! -z $module_repo ]]
}

function get_module_repo() {
  local module_name=$1
  module_repo="$(jq --arg var "$module_name" -r '(.modules[] | select(any(.==$var))) | .pip' ./openimis-be_py/openimis.json | sed -e "s/git+\(.\+\)#.\+/\1/")"
  [[ -z $module_repo ]] && {
    echo "The module $2 is unknown."
    exit 1
  }
  echo $module_repo
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
    cd openimis-dist_dkr
    [[ -L openimis-be_py ]] || ln -fs ../openimis-be_py
    [[ -L modules ]] || ln -fs ../modules
  )

  echo
  echo "Generating Dockerfile to customized backend Docker image"
  cat ./openimis-be_py/Dockerfile | sed -e "s/\(FROM python:3.8-buster\)/\1 AS ORIGIN/" >Dockerfile
  cat Dockerfile.override >>Dockerfile
  ;;

"ps")
  dckr-compose ps
  ;;

"shell")
  warmup
  echo "Entering interactive shell:"
  dckr-compose exec -ti backend bash
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
  known_module $module_name || (
    echo "The module $2 is unknown."
    exit 1
  )
  warmup
  echo "Running test for module ${module_name}"
  dckr-compose exec backend bash -c "python manage.py test --keepdb $module_name"
  ;;

"workon")
  module_name=$2
  module_repo=$(get_module_repo $module_name)
  echo "Cloning $module_name from $module_repo"
  clone_module $module_name $module_repo
  module_repo_name=$(get_name_from_git_repo $module_repo)
  echo "Switching from remote version to local version for $module_name"
  echo "From $module_repo to ./modules/${module_repo_name}"

  warmup
  dckr-compose exec backend bash -c "pip uninstall -y openimis-be-${module_name}"
  dckr-compose exec backend bash -c "pip install -e ../../modules/${module_repo_name}/"
  ;;

"stop")
  echo "Stopping everything"
  dckr-compose down
  ;;

*)
  usage
  ;;

esac
