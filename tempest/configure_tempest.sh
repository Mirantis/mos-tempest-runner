#!/bin/bash

TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/init_env_variables.sh

check_service_availability() {
    local service_count="$(keystone service-list 2>/dev/null | grep $1 | wc -l)"
    if [ "${service_count}" -eq "0" ]; then
        echo "false"
    else
        echo "true"
    fi
}

init_some_config_options() {
    IS_NEUTRON_AVAILABLE=$(check_service_availability "neutron")
    if [ "${IS_NEUTRON_AVAILABLE}" = "true" ]; then
        PUBLIC_NETWORK_ID="$(neutron net-list --router:external=true -f csv -c id --quote none | tail -1)"
        PUBLIC_ROUTER_ID="$(neutron router-list --external_gateway_info:network_id=${PUBLIC_NETWORK_ID} -F id -f csv --quote none | tail -1)"
    fi

    IMAGE_REF="$(glance image-list --name TestVM | grep TestVM | awk '{print $2}')"

    OS_EC2_URL="$(keystone catalog --service ec2 2>/dev/null | grep publicURL | awk '{print $4}')"
    OS_S3_URL="$(keystone catalog --service s3 2>/dev/null | grep publicURL | awk '{print $4}')"
    OS_DASHBOARD_URL=${OS_AUTH_URL/:5000\/v2.0/\/horizon\/}
    local controller_os="$(ssh ${CONTROLLER_HOST} "cat /etc/*-release | head -n 1 | awk '{print \$1}'" 2>/dev/null)"
    if [ "${controller_os}" = "CentOS" ]; then
        OS_DASHBOARD_URL=${OS_DASHBOARD_URL/horizon/dashboard}
    fi

    CINDER_STORAGE_PROTOCOL="iSCSI"
    local volume_driver="$(ssh ${CONTROLLER_HOST} "cat /etc/cinder/cinder.conf | grep volume_driver" 2>/dev/null)"
    if [ "$(echo ${volume_driver} | grep -o RBDDriver)" ]; then
        CINDER_STORAGE_PROTOCOL="ceph"
    fi
}

create_config_file() {
    local tempest_conf="${DEST}/tempest/etc/tempest.conf"
    if [ -f ${tempest_conf} ]; then
        message "Tempest config file already exists!"
    else
        message "Configuring Tempest"
        init_some_config_options
        cat > ${tempest_conf} <<EOF
[DEFAULT]
debug = ${DEBUG:-false}
use_stderr = ${USE_STDERR:-false}
lock_path = /tmp
log_file = tempest.log

[auth]
tempest_roles = _member_

[boto]
ec2_url = ${OS_EC2_URL}
s3_url = ${OS_S3_URL}
http_socket_timeout = 30

[cli]
cli_dir = ${DEST}/.venv/bin
has_manage = false

[compute]
image_ref = ${IMAGE_REF}
image_ref_alt = ${IMAGE_REF}
flavor_ref = 0
flavor_ref_alt = 42
ssh_user = cirros
image_ssh_user = cirros
image_alt_ssh_user = cirros
fixed_network_name=net04
network_for_ssh=net04_ext
build_timeout = 300
allow_tenant_isolation = true

[compute-feature-enabled]
live_migration = false
resize = true
vnc_console = true

[dashboard]
login_url = ${OS_DASHBOARD_URL}auth/login/
dashboard_url = ${OS_DASHBOARD_URL}project/

[identity]
admin_domain_name = Default
admin_password = ${OS_PASSWORD}
admin_tenant_name = ${OS_TENANT_NAME}
admin_username = ${OS_USERNAME}
password = demo
tenant_name = demo
username = demo
uri = ${OS_AUTH_URL}
uri_v3 = ${OS_AUTH_URL/v2.0/v3}

[network]
public_network_id = ${PUBLIC_NETWORK_ID}

[network-feature-enabled]
api_extensions = ext-gw-mode,security-group,l3_agent_scheduler,binding,quotas,dhcp_agent_scheduler,multi-provider,agent,external-net,router,metering,allowed-address-pairs,extra_dhcp_opt,extraroute

[object-storage]
operator_role = SwiftOperator

[scenario]
img_dir = ${DEST}/.venv/files
ami_img_file = cirros-0.3.2-x86_64-blank.img
ari_img_file = cirros-0.3.2-x86_64-initrd
aki_img_file = cirros-0.3.2-x86_64-vmlinuz
large_ops_number = 5

[service_available]
ceilometer = $(check_service_availability "ceilometer")
cinder = $(check_service_availability "cinder")
glance = $(check_service_availability "glance")
heat = $(check_service_availability "heat")
neutron = ${IS_NEUTRON_AVAILABLE}
nova = $(check_service_availability "nova")
sahara = $(check_service_availability "sahara")
swift = $(check_service_availability "swift")

[volume]
build_timeout = 300
storage_protocol = ${CINDER_STORAGE_PROTOCOL}

[volume-feature-enabled]
backup = false
EOF
    fi

    export TEMPEST_CONFIG_DIR="$(dirname "${tempest_conf}")"
    export TEMPEST_CONFIG="$(basename "${tempest_conf}")"

    message "Tempest config file:"
    cat ${tempest_conf}
    message "You can override the config options in ${tempest_conf}"
}

create_config_file
