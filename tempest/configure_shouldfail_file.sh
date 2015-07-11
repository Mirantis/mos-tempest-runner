#!/bin/bash

TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/init_env_variables.sh

FUEL_RELEASE_DIR="$(echo ${FUEL_RELEASE} | sed "s/\./_/g")"
SHOULDFAIL_FILE=${DEST}/shouldfail/shouldfail.yaml

add_shouldfail_tests_for_ceph_eph_volumes() {
    # If Ceph is used as backend for ephemeral volumes, add "shouldfail" tests related to Ceph ephemeral volumes to "shouldfail" file
    local is_ceph_ephemeral_volumes="$(ssh ${COMPUTE_HOST} "cat /etc/nova/nova.conf | grep images_type=rbd" 2>/dev/null)"
    if [ "${is_ceph_ephemeral_volumes}" -a -f ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/ceph_eph_volumes ]; then
        cat ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/ceph_eph_volumes >> ${SHOULDFAIL_FILE}
    fi
}

add_shouldfail_tests_for_cinder_lvm() {
    # If LVM is used as Cinder backend, add "shouldfail" tests related to LVM to "shouldfail" file
    local volume_driver="$(ssh ${CONTROLLER_HOST} "cat /etc/cinder/cinder.conf | grep volume_driver" 2>/dev/null)"
    if [ ! "$(echo ${volume_driver} | grep -o RBDDriver)" -a -f ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/cinder_lvm ]; then
        cat ${DEST}/shouldfail/${FUEL_RELEASE_DIR}/cinder_lvm >> ${SHOULDFAIL_FILE}
    fi
}

add_shouldfail_tests_for_swift() {
    # If Swift is deployed, add "shouldfail" tests related to Swift to "shouldfail" file
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

            add_shouldfail_tests_for_ceph_eph_volumes
            add_shouldfail_tests_for_cinder_lvm
            add_shouldfail_tests_for_swift
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
