#!/bin/bash

USER_NAME="${USER_NAME:-developer}"
USER_HOME_DIR="/home/${USER_NAME}"
DEST="${USER_HOME_DIR}/mos-tempest-runner"
VIRTUALENV_DIR="${DEST}/.venv"
TEMPEST_REPORTS_DIR="${DEST}/tempest-reports"

PYTHON_VERSION="${PYTHON_VERSION:-2.7.9}"
PYTHON_LOCATION="https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"

PIP_LOCATION="https://bootstrap.pypa.io/get-pip.py"

CIRROS_VERSION="${CIRROS_VERSION:-0.3.2}"
CIRROS_UEC_IMAGE_URL="http://download.cirros-cloud.net/${CIRROS_VERSION}/cirros-${CIRROS_VERSION}-x86_64-uec.tar.gz"
CIRROS_DISK_IMAGE_URL="http://download.cirros-cloud.net/${CIRROS_VERSION}/cirros-${CIRROS_VERSION}-x86_64-disk.img"

KEYSTONE_HAPROXY_CONFIG_PATH="${KEYSTONE_HAPROXY_CONFIG_PATH:-/etc/haproxy/conf.d/030-keystone-2.cfg}"

# Tempest commit ID from Sep 9, 2015.
default_tempest_commit_id="d05a3c26cd1b492c0466737972ea05d339f224d6"
TEMPEST_COMMIT_ID="${TEMPEST_COMMIT_ID:-${default_tempest_commit_id}}"

# TLS related options
REMOTE_CA_CERT="${REMOTE_CA_CERT:-/var/lib/astute/haproxy/public_haproxy.pem}"
LOCAL_CA_CERT="${LOCAL_CA_CERT:-${USER_HOME_DIR}/public_haproxy.pem}"

# Helper functions
message() {
    printf "\e[33m%s\e[0m\n" "${1}"
}

error() {
    printf "\e[31mError: %s\e[0m\n" "${*}" >&2
}

remote_cli() {
    ssh ${CONTROLLER_HOST} ". openrc; $@"
}
