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

add_workaround_for_bug_1427782() {
    # TODO(ylobankov): remove this workaround after the bug #1427782 is fixed.
    local controller_os="$(ssh ${CONTROLLER_HOST} "cat /etc/*-release | head -n 1 | awk '{print \$1}'" 2>/dev/null)"
    if [ "${controller_os}" = "CentOS" -a ! "$(cat ${SHOULDFAIL_FILE} | grep ImagesOneServerTestJSON)" ]; then
            cat >> ${SHOULDFAIL_FILE} <<EOF

# Nova
- tempest.api.compute.images.test_images_oneserver.ImagesOneServerTestJSON.test_create_image_specify_multibyte_character_image_name[id-3b7c6fe4-dfe7-477c-9243-b06359db51e6]:
    Fail because of https://bugs.launchpad.net/mos/+bug/1427782
EOF
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

        add_workaround_for_bug_1427782
    else
        message "'Shouldfail' file already exists!"
    fi

    message "'Shouldfail' tests:"
    cat ${SHOULDFAIL_FILE}
    message "You can override the 'shouldfail' tests in ${SHOULDFAIL_FILE}"
}

choose_and_configure_shouldfail_file
