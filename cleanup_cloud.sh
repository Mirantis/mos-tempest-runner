#!/bin/bash -x

TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/helpers/init_env_variables.sh

CONTROLLER_HOST="node-$(fuel node "$@" | grep controller | awk '{print $1}' | head -1)"
TOKEN="$(ssh ${CONTROLLER_HOST} egrep "^admin_token.*" /etc/keystone/keystone.conf 2>/dev/null | cut -d'=' -f2)"
OS_AUTH_URL="$(ssh ${CONTROLLER_HOST} ". openrc; keystone catalog --service identity 2>/dev/null | grep publicURL | awk '{print \$4}'")"


keystone_adm() {
    remote_cli keystone --os-token ${TOKEN} --os-endpoint ${OS_AUTH_URL/5000/35357} $@
}

restore_service_catalog() {
    message "Revert Keystone endpoints"
    local identity_service_id="$(keystone_adm service-list | grep identity | awk '{print $2}')"
    local old_endpoint="$(keystone_adm endpoint-list | grep ${identity_service_id} | awk '{print $2}')"
    local internal_url="$(ssh ${CONTROLLER_HOST} ". openrc; keystone catalog --service identity 2>/dev/null | grep internalURL | awk '{print \$4}'")"
    keystone_adm endpoint-create --region RegionOne --service ${identity_service_id} --publicurl ${OS_AUTH_URL} --adminurl ${internal_url/5000/35357} --internalurl ${internal_url} 2>/dev/null
    if [ ! -z ${old_endpoint} ]; then
        keystone_adm endpoint-delete ${old_endpoint} 2>/dev/null
    fi
}

cleanup_cloud() {

    restore_service_catalog

    message "Delete the created user, tenant and roles"
    keystone_adm user-role-remove --role SwiftOperator --user demo --tenant demo 2>/dev/null || true
    keystone_adm user-role-remove --role anotherrole --user demo --tenant demo 2>/dev/null || true
    keystone_adm user-role-remove --role admin --user admin --tenant demo 2>/dev/null || true

    keystone_adm role-delete SwiftOperator 2>/dev/null || true
    keystone_adm role-delete anotherrole 2>/dev/null || true
    keystone_adm role-delete heat_stack_user 2>/dev/null || true
    keystone_adm role-delete heat_stack_owner 2>/dev/null || true
    keystone_adm role-delete ResellerAdmin 2>/dev/null || true

    keystone_adm user-delete demo 2>/dev/null || true
    keystone_adm tenant-delete demo 2>/dev/null || true

    message "Delete the created flavors"
    remote_cli nova flavor-delete m1.tempest-nano || true
    remote_cli nova flavor-delete m1.tempest-micro || true

    message "Delete the uploaded CirrOS image"
    remote_cli glance image-delete cirros-${CIRROS_VERSION}-x86_64 || true

    message "Cleanup is done!"
}

cleanup_cloud
