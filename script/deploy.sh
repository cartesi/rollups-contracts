#!/usr/bin/env bash

set -euo pipefail

cd "${BASH_SOURCE%/*}/.."

forge script DeploymentScript "$@"
