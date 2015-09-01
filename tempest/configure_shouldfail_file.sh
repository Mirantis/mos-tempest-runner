#!/bin/bash

TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/init_env_variables.sh

FUEL_RELEASE_DIR="$(echo ${FUEL_RELEASE} | sed "s/\./_/g")"
SHOULDFAIL_FILE=${DEST}/shouldfail/shouldfail.yaml

add_shouldfail_tests_from_ceph_eph_volumes_file() {
    # If Ceph is used as backend for ephemeral volumes, add "shouldfail" tests from ceph_eph_volumes file to shouldfail.yaml file
    local is_ceph_ephemeral_volumes="$(ssh ${COMPUTE_HOST} "cat /etc/nova/nova.conf | grep images_type=rbd" 2>/dev/null)"
    if [ "${is_ceph_ephemeral_volumes}" -a -f ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/ceph_eph_volumes ]; then
        cat ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/ceph_eph_volumes >> ${SHOULDFAIL_FILE}
    fi
}

add_shouldfail_tests_from_ceph_volumes_file() {
    # If Ceph is used as Cinder backend, add "shouldfail" tests from ceph_volumes file to shouldfail.yaml file
    local volume_driver="$(ssh ${CONTROLLER_HOST} "cat /etc/cinder/cinder.conf | grep volume_driver" 2>/dev/null)"
    if [ "$(echo ${volume_driver} | grep -o RBDDriver)" -a -f ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/ceph_volumes ]; then
        cat ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/ceph_volumes >> ${SHOULDFAIL_FILE}
    fi
}

add_shouldfail_tests_from_lvm_volumes_file() {
    # If LVM is used as Cinder backend, add "shouldfail" tests from lvm_volumes file to shouldfail.yaml file
    local volume_driver="$(ssh ${CONTROLLER_HOST} "cat /etc/cinder/cinder.conf | grep volume_driver" 2>/dev/null)"
    if [ ! "$(echo ${volume_driver} | grep -o RBDDriver)" -a -f ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/lvm_volumes ]; then
        cat ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/lvm_volumes >> ${SHOULDFAIL_FILE}
    fi
}

add_shouldfail_tests_from_swift_file() {
    # If Swift is deployed, add "shouldfail" tests from swift file to shouldfail.yaml file
    local is_swift="$(ssh ${CONTROLLER_HOST} "if [ -d /etc/swift ]; then echo true; else echo false; fi")"
    if [ "${is_swift}" = "true" -a -f ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/swift ]; then
        cat ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/swift >> ${SHOULDFAIL_FILE}
    fi
}

choose_and_configure_shouldfail_file() {
    message "Configuring 'shouldfail' file"

    if [ ! -f ${SHOULDFAIL_FILE} ]; then
        if [ -f ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/shouldfail.yaml ]; then
            cp ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/shouldfail.yaml ${SHOULDFAIL_FILE}

            add_shouldfail_tests_from_ceph_eph_volumes_file
            add_shouldfail_tests_from_ceph_volumes_file
            add_shouldfail_tests_from_lvm_volumes_file
            add_shouldfail_tests_from_swift_file
        else
            # Use default "shouldfail" file
            cp ${DEST}/shouldfail/default_shouldfail.yaml ${SHOULDFAIL_FILE}
        fi
    else
        message "'Shouldfail' file already exists!"
    fi

    message "'Shouldfail' tests:"
    cat ${SHOULDFAIL_FILE}
    message "You can override the 'shouldfail' tests in ${SHOULDFAIL_FILE}"
}

choose_and_configure_shouldfail_file
