# OpenIMIS Devevelopment

Offers a ready to use environment and documentation to develop the OpenIMIS
Python Backend.

## Requirements

* Docker 23+
* jq 1.6+
* Bash
* Linux system

## Tools

One tool is provided to manage, runs, and uses the dev environment: `run.sh`

```bash
./run.sh

  Runs command and tools in a containerized environment for the development of
  the backend.

  bootstrap     bootstraps the development environment
  default       sets the default service to interact with (shell)
  disable       disables a given service (backend and db can't be disabled)
  enable        enables a given service (by default db and backend are run)
  logs          prints the logs for the given service
  prepare_test  prepares the test environment in backend, in particular the database    
  refresh       refreshes a service by rebuilding its image and (re)starting it
  server        runs the backend server
  settings      reads current settings if any
  shell         runs an interactive shell on the default service
  status        returns current status of the environment
  stop          stops the environment if running
  test          runs test for given module in backend
  workon        switches a module in backend for its local version for development
```

## Documentation

There are many materials useful to the developer. If we focus on the backend,
we advise to go through the following list

1. Read [the README of the GitHub project](https://github.com/openimis/openimis-be_py#openimis-backend-reference-implementation--windows-docker)
2. Watch a few videos about the architecture and the backend that you can find in the wikipage [Developer Starter Kit](https://openimis.atlassian.net/wiki/spaces/OP/pages/1277493249/Developer+Starter+Kit)
3. If you need info about the usage of its legacy version, read the [technical user manual](https://docs.openimis.org/en/latest/)
4. If you want a quick overview of the architecture in modules, read the [wikipage openIMIS modules](https://openimis.atlassian.net/wiki/spaces/OP/pages/589561955/openIMIS+Modules). Find also there the doc for each module.
5. If you want to go further especially understand the management of the project and related aspects, go to [the entry point in OpenIMIS wiki for development](https://openimis.atlassian.net/wiki/spaces/OP/pages/215613450/openIMIS+Development)