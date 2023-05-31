# OpenIMIS Devevelopment

Offers a ready to use environment and documentation to develop the OpenIMIS
Python Backend.

## Requirements

* Docker 23+
* jq 1.6+
* Bash
* Linux system

## Run dev environment

One tool is provided to manage, runs, and uses the dev environment: `run.sh`

```bash
./run.sh                                                                                                                                                          

  Runs command and tools in a containerized environment for the development of
  the backend.

  ./run.sh COMMAND [parameters]

  COMMANDS:

  bootstrap       bootstraps the development environment.
  compose <args>  runs any Docker compose command.
  db  [name]      sets and uses the database type (restart if running) or gets
                  it if nothing passed.
                  possible values: ${VALID_DATABASES}
  dbshell         runs an interactive shell in the running db.
  default [name]  sets the default service to interact with (shell) or gets it
                  if nothing passed.
  disable <name>  disables a given service (backend and db can't be disabled).
  enable  <name>  enables a given service (db and backend are mandatory).
                  possible values: $(available_services | tr '\r\n' ',' | sed "s/.$//")
  enabled         lists enabled services.
  modules         lists known backend modules.
  logs <name>     prints the logs for the given service.
  prepare_db      prepares the database (required before running test in backend)
  purge           stops and removes all containers and volumes.
  refresh <name>  refreshes a service by rebuilding its image and (re)starting
                  it.
  server          runs the backend server in background.
  servershell     runs an interactive python shell with the backend server.
  settings        reads current settings if any.
  shell [name]    runs an interactive shell on the given service or the default
                  one if nothing passed.
  shutdown        stops the backend server.
  status          returns current status of the environment.
  stop            stops the environment if running.
  test            runs test for given module in backend.
  warmup          warms up enabled services.
  workon <name>   switches a module in backend for its local version for
                  development.
```

## Tools

In the directory [`tools`](tools/), you'll find some tools useful during dev:

* `cs_rest_api_mobile_pact.sh` is a scenario of HTTP requests made at
  the C# REST API to reproduce the ones made by the claims mobile app. This
  might be deleted when the migration to FHIR is done.
* `fhir_mobile_pact.sh` is a scenario of HTTP requests made at FHIR REST API
  exposed through the Django backend server.

Those tools must be run outside the containers. They might require the gateway
service so they can connect to their respective HTTP servers.

## Documentation

There are many materials useful to the developer. If we focus on the backend,
we advise to go through the following list

1. Read [the README of the GitHub project](https://github.com/openimis/openimis-be_py#openimis-backend-reference-implementation--windows-docker)
2. Watch a few videos about the architecture and the backend that you can find in the wikipage [Developer Starter Kit](https://openimis.atlassian.net/wiki/spaces/OP/pages/1277493249/Developer+Starter+Kit)
3. If you need info about the usage of its legacy version, read the [technical user manual](https://docs.openimis.org/en/latest/)
4. If you want a quick overview of the architecture in modules, read the [wikipage openIMIS modules](https://openimis.atlassian.net/wiki/spaces/OP/pages/589561955/openIMIS+Modules). Find also there the doc for each module.
5. If you want to go further especially understand the management of the project and related aspects, go to [the entry point in OpenIMIS wiki for development](https://openimis.atlassian.net/wiki/spaces/OP/pages/215613450/openIMIS+Development)