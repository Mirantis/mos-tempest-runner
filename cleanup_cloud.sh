#!/bin/bash -x

TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/helpers/init_env_variables.sh

cleanup_cloud() {
    source ${VIRTUALENV_DIR}/bin/activate
    source ${USER_HOME_DIR}/openrc

    message "Delete the created user, tenant and roles"
    keystone user-role-remove --role SwiftOperator --user demo --tenant demo 2>/dev/null || true
    keystone user-role-remove --role anotherrole --user demo --tenant demo 2>/dev/null || true
    keystone user-role-remove --role admin --user admin --tenant demo 2>/dev/null || true

    keystone role-delete SwiftOperator 2>/dev/null || true
    keystone role-delete anotherrole 2>/dev/null || true
    keystone role-delete heat_stack_user 2>/dev/null || true
    keystone role-delete heat_stack_owner 2>/dev/null || true
    keystone role-delete ResellerAdmin 2>/dev/null || true

    keystone user-delete demo 2>/dev/null || true
    keystone tenant-delete demo 2>/dev/null || true

    message "Delete the created flavors"
    nova flavor-delete m1.tempest-nano || true
    nova flavor-delete m1.tempest-micro || true

    message "Delete the uploaded CirrOS image"
    glance image-delete cirros-${CIRROS_VERSION}-x86_64 || true

    message "Revert Keystone endpoints"
    local identity_service_id="$(ssh ${CONTROLLER_HOST} ". openrc; keystone service-list 2>/dev/null | grep identity | awk '{print \$2}'")"
    local internal_url="$(ssh ${CONTROLLER_HOST} ". openrc; keystone endpoint-list 2>/dev/null | grep ${identity_service_id} | awk '{print \$8}'")"
    local old_endpoint="$(ssh ${CONTROLLER_HOST} ". openrc; keystone endpoint-list 2>/dev/null | grep ${identity_service_id} | awk '{print \$2}'")"
    ssh ${CONTROLLER_HOST} ". openrc; keystone endpoint-create --region RegionOne --service ${identity_service_id} --publicurl ${OS_AUTH_URL} --adminurl ${internal_url/5000/35357} --internalurl ${internal_url} 2>/dev/null"
    ssh ${CONTROLLER_HOST} ". openrc; keystone endpoint-delete ${old_endpoint} 2>/dev/null"
}

cleanup_cloud
