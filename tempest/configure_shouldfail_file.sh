#!/bin/bash

TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/init_env_variables.sh

choose_and_configure_shouldfail_file() {
    message "Configuring 'shouldfail' file"

    local shouldfail_file=${DEST}/shouldfail/shouldfail.yaml
    local fuel_release="$(echo ${FUEL_RELEASE} | sed "s/\./_/g")"
    if [ ! -f ${shouldfail_file} ]; then
        if [ -f ${DEST}/shouldfail/${fuel_release}/shouldfail.yaml ]; then
            cp ${DEST}/shouldfail/${fuel_release}/shouldfail.yaml ${shouldfail_file}
        else
            # Use default "shouldfail" file
            cp ${DEST}/shouldfail/default_shouldfail.yaml ${shouldfail_file}
        fi

        # If LVM is used as Cinder backend, add "shouldfail" tests related to LVM to "shouldfail" file
        local volume_driver="$(ssh ${CONTROLLER_HOST} "cat /etc/cinder/cinder.conf | grep volume_driver" 2>/dev/null)"
        local cinder_lvm_shouldfail_file=${DEST}/shouldfail/${fuel_release}/cinder_lvm
        if [ ! "$(echo ${volume_driver} | grep -o RBDDriver)" -a -f ${cinder_lvm_shouldfail_file} ]; then
            cat ${DEST}/shouldfail/${fuel_release}/cinder_lvm >> ${shouldfail_file}
        fi

        # If Swift is deployed, add "shouldfail" tests related to Swift to "shouldfail" file
        local is_swift="$(ssh ${CONTROLLER_HOST} "if [ -d /etc/swift ]; then echo true; else echo false; fi")"
        local swift_shouldfail_file=${DEST}/shouldfail/${fuel_release}/swift
        if [ "${is_swift}" = "true" -a -f ${swift_shouldfail_file} ]; then
            cat ${DEST}/shouldfail/${fuel_release}/swift >> ${shouldfail_file}
        fi

        # If Ceph is used as backend for ephemeral volumes, add "shouldfail" tests related to Ceph ephemeral volumes to "shouldfail" file
        local is_ceph_ephemeral_volumes="$(ssh ${COMPUTE_HOST} "cat /etc/nova/nova.conf | grep images_type=rbd" 2>/dev/null)"
        local ceph_eph_volumes_shouldfail_file=${DEST}/shouldfail/${fuel_release}/ceph_eph_volumes
        if [ "${is_ceph_ephemeral_volumes}" -a -f ${ceph_eph_volumes_shouldfail_file} ]; then
            cat ${DEST}/shouldfail/${fuel_release}/ceph_eph_volumes >> ${shouldfail_file}
        fi

        #TODO(ylobankov): remove this workaround after the bug #1427782 is fixed
        local controller_os="$(ssh ${CONTROLLER_HOST} "cat /etc/*-release | head -n 1 | awk '{print \$1}'" 2>/dev/null)"
        if [ "${controller_os}" = "CentOS" -a ! "$(cat ${shouldfail_file} | grep ImagesOneServerTestJSON)" ]; then
                cat >> ${shouldfail_file} <<EOF

# Nova
- tempest.api.compute.images.test_images_oneserver.ImagesOneServerTestJSON.test_create_image_specify_multibyte_character_image_name[gate,id-3b7c6fe4-dfe7-477c-9243-b06359db51e6]:
    Fail because of https://bugs.launchpad.net/mos/+bug/1427782
EOF
        fi

    else
        message "'Shouldfail' file already exists!"
    fi

    message "'Shouldfail' tests:"
    cat ${shouldfail_file}
    message "You can override the 'shouldfail' tests in ${shouldfail_file}"
}

choose_and_configure_shouldfail_file
