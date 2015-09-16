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
        PUBLIC_NETWORK_ID="$(neutron net-list --router:external=true -f csv -c id --quote none 2>/dev/null | tail -1)"
        PUBLIC_ROUTER_ID="$(neutron router-list --external_gateway_info:network_id=${PUBLIC_NETWORK_ID} -F id -f csv --quote none 2>/dev/null | tail -1)"
    fi

    IMAGE_REF="$(glance image-list 2>/dev/null | grep cirros-${CIRROS_VERSION}-x86_64 | awk '{print $2}')"
    IMAGE_REF_ALT="$(glance image-list 2>/dev/null | grep TestVM | awk '{print $2}')"

    OS_EC2_URL="$(keystone catalog --service ec2 2>/dev/null | grep publicURL | awk '{print $4}')"
    OS_S3_URL="$(keystone catalog --service s3 2>/dev/null | grep publicURL | awk '{print $4}')"

    ATTACH_ENCRYPTED_VOLUME="true"
    VOLUMES_STORAGE_PROTOCOL="iSCSI"
    VOLUMES_BACKUP="false"

    local volume_driver="$(ssh ${CONTROLLER_HOST} "cat /etc/cinder/cinder.conf | grep volume_driver" 2>/dev/null)"
    if [ "$(echo ${volume_driver} | grep -o RBDDriver)" ]; then
        ATTACH_ENCRYPTED_VOLUME="false"
        VOLUMES_STORAGE_PROTOCOL="ceph"
        # In MOS 7.0 volumes backup works only if the volumes storage protocol is Ceph
        VOLUMES_BACKUP="true"
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
verbose = ${VERBOSE:-false}
use_stderr = ${USE_STDERR:-false}
log_dir = ${TEMPEST_REPORTS_DIR}
log_file = tempest.log

[oslo_concurrency]
lock_path = /tmp

[boto]
ec2_url = ${OS_EC2_URL}
s3_url = ${OS_S3_URL}
http_socket_timeout = 30

[compute]
image_ref = ${IMAGE_REF}
image_ref_alt = ${IMAGE_REF_ALT}
flavor_ref = 0
flavor_ref_alt = 42
ssh_user = cirros
image_ssh_user = cirros
image_alt_ssh_user = cirros
build_timeout = 300

[compute-feature-enabled]
live_migration = false
resize = true
vnc_console = true
preserve_ports = true
attach_encrypted_volume = ${ATTACH_ENCRYPTED_VOLUME}

[dashboard]
dashboard_url = http://${OS_PUBLIC_IP}/

[data_processing-feature-enabled]
plugins = vanilla,cdh,mapr,spark,ambari

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
ca_certificates_file = ${OS_CACERT}

[image-feature-enabled]
deactivate_image = true

[network]
public_network_id = ${PUBLIC_NETWORK_ID}

[network-feature-enabled]
api_extensions = security-group,l3_agent_scheduler,ext-gw-mode,binding,metering,agent,quotas,dhcp_agent_scheduler,l3-ha,multi-provider,external-net,router,allowed-address-pairs,extraroute,extra_dhcp_opt,provider,dvr
ipv6_subnet_attributes = true
ipv6 = true

[object-storage]
operator_role = SwiftOperator

[orchestration]
max_template_size = 5440000
max_resources_per_stack = 20000

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

[telemetry]
too_slow_to_test = false

[validation]
run_validation = true

[volume]
build_timeout = 300
storage_protocol = ${VOLUMES_STORAGE_PROTOCOL}

[volume-feature-enabled]
# In MOS 7.0 volumes backup works only if the volumes storage protocol is Ceph
backup = ${VOLUMES_BACKUP}
bootable = true
EOF
    fi

    export TEMPEST_CONFIG_DIR="$(dirname "${tempest_conf}")"
    export TEMPEST_CONFIG="$(basename "${tempest_conf}")"

    message "Tempest config file:"
    cat ${tempest_conf}
    message "You can override the config options in ${tempest_conf}"
}

create_config_file
