#!/bin/bash

USER_NAME="${USER_NAME:-developer}"
USER_HOME_DIR="/home/${USER_NAME}"
DEST="${USER_HOME_DIR}/mos-tempest-runner"
VIRTUALENV_DIR="${DEST}/.venv"
PYTHON_VERSION="${PYTHON_VERSION:-2.7.9}"
PYTHON_LOCATION="https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"
PIP_LOCATION="https://raw.github.com/pypa/pip/master/contrib/get-pip.py"
CIRROS_VERSION="${CIRROS_VERSION:-0.3.2}"
CIRROS_IMAGE_URL="http://download.cirros-cloud.net/${CIRROS_VERSION}/cirros-${CIRROS_VERSION}-x86_64-uec.tar.gz"
TEMPEST_REPORTS_DIR="${DEST}/tempest-reports"

# Helper functions
message() {
    printf "\e[33m%s\e[0m\n" "${1}"
}

error() {
    printf "\e[31mError: %s\e[0m\n" "${*}" >&2
}
