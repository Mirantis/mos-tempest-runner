#!/bin/bash -xe

TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/helpers/init_env_variables.sh

install_system_requirements() {
    message "Enable default CentOS repo"
    yum -y reinstall centos-release

    message "Installing system requirements"
    yum -y install git
    yum -y install gcc
    yum -y install zlib-devel
    yum -y install readline-devel
    yum -y install bzip2-devel
    yum -y install libgcrypt-devel
    yum -y install openssl-devel
    yum -y install libffi-devel
    yum -y install libxml2-devel
    yum -y install libxslt-devel
    yum -y install python-devel
    yum -y install python-pip
}

install_python27_pip_virtualenv() {
    message "Installing Python 2.7"
    if command -v python2.7 &>/dev/null; then
        message "Python 2.7 already installed!"
    else
        local temp_dir="$(mktemp -d)"
        cd ${temp_dir}
        wget ${PYTHON_LOCATION}
        tar xzf Python-${PYTHON_VERSION}.tgz
        cd Python-${PYTHON_VERSION}
        ./configure --prefix=/usr/local --enable-unicode=ucs4 --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib"
        make -j5 altinstall
    fi

    message "Installing Pip 2.7"
    if command -v pip2.7 &>/dev/null; then
        message "Pip 2.7 already installed!"
    else
        message "Installing pip for Python 2.7"
        local get_pip_file="$(mktemp)"
        wget -O ${get_pip_file} ${PIP_LOCATION}
        python2.7 ${get_pip_file}
        pip2.7 install -U tox
    fi

    message "Installing virtualenv"
    if command -v virtualenv &>/dev/null; then
        message "virtualenv already installed!"
    else
        message "Installing virtualenv for Python 2.7"
        pip2.7 install virtualenv
    fi
}

init_cluster_variables() {
    message "Initialize cluster variables"

    CONTROLLER_HOST="$(fuel node "$@" | grep controller | awk -F\| '{print $5}' | head -1 | sed -e s/[[:space:]]//g)"
    message "Controller host is '${CONTROLLER_HOST}'"

    COMPUTE_HOST="$(fuel node "$@" | grep compute | awk -F\| '{print $5}' | head -1 | sed -e s/[[:space:]]//g)"
    message "Compute host is '${COMPUTE_HOST}'"

    FUEL_RELEASE="$(fuel --fuel-version 2>&1 | grep -e ^release: | awk '{print $2}' | sed "s/'//g")"
    message "Fuel release is ${FUEL_RELEASE}"

    case ${FUEL_RELEASE} in
        "7.0") TEMPEST_COMMIT_ID="c5bb7663b618a91b15d379fb5b2550e238566ce6";;
        "8.0") TEMPEST_COMMIT_ID="9ccf77af488c3b6464356b6fab106ec78e3b7c51";;
    esac

    OS_PUBLIC_AUTH_URL="$(ssh ${CONTROLLER_HOST} ". openrc; keystone catalog --service identity 2>/dev/null | grep publicURL | awk '{print \$4}'")"
    OS_PUBLIC_IP="$(ssh ${CONTROLLER_HOST} "grep -w public_vip /etc/hiera/globals.yaml | awk '{print \$2}' | sed 's/\"//g'")"
    message "OS_PUBLIC_AUTH_URL = ${OS_PUBLIC_AUTH_URL}"
    message "OS_PUBLIC_IP = ${OS_PUBLIC_IP}"

    local htts_public_endpoint="$(ssh ${CONTROLLER_HOST} ". openrc; keystone catalog --service identity 2>/dev/null | grep https")"
    if [ "${htts_public_endpoint}" ]; then
        TLS_ENABLED="yes"
        message "TLS_ENABLED = yes"
    else
        TLS_ENABLED="no"
        message "TLS_ENABLED = no"
    fi
}

configure_env() {
    message "Create and configure environment"

    id -u ${USER_NAME} &>/dev/null || useradd -m ${USER_NAME}
    grep nofile /etc/security/limits.conf || echo '* soft nofile 50000' >> /etc/security/limits.conf ; echo '* hard nofile 50000' >> /etc/security/limits.conf

    mkdir -p ${DEST}

    # SSH
    cp -r /root/.ssh ${USER_HOME_DIR}
    echo "User root" >> ${USER_HOME_DIR}/.ssh/config

    # bashrc
    cat > ${USER_HOME_DIR}/.bashrc <<EOF
test "\${PS1}" || return
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
alias ls=ls\ --color=auto
alias ll=ls\ --color=auto\ -lhap
echo \${PATH} | grep ":\${HOME}/bin" >/dev/null || export PATH="\${PATH}:\${HOME}/bin"
if [ \$(id -u) -eq 0 ]; then
    export PS1='\[\033[01;41m\]\u@\h:\[\033[01;44m\] \W \[\033[01;41m\] #\[\033[0m\] '
else
    export PS1='\[\033[01;33m\]\u@\h\[\033[01;0m\]:\[\033[01;34m\]\W\[\033[01;0m\]$ '
fi
cd ${DEST}
source ${VIRTUALENV_DIR}/bin/activate
source ${USER_HOME_DIR}/openrc
EOF

    # vimrc
    cat > ${USER_HOME_DIR}/.vimrc <<EOF
filetype plugin indent off
syntax on

set nowrap
set nocompatible
set expandtab
set tabstop=4
set shiftwidth=4
set smarttab
set et
set wrap
set showmatch
set hlsearch
set incsearch
set ignorecase
set lz
set listchars=tab:··
set list
set ffs=unix,dos,mac
set fencs=utf-8,cp1251,koi8-r,ucs-2,cp866
EOF

    # openrc
    scp ${CONTROLLER_HOST}:/root/openrc ${USER_HOME_DIR}/openrc
    sed -i "/LC_ALL.*/d" ${USER_HOME_DIR}/openrc
    sed -i "/OS_AUTH_URL.*/d" ${USER_HOME_DIR}/openrc
    sed -i "s/internalURL/publicURL/g" ${USER_HOME_DIR}/openrc
    echo "export FUEL_RELEASE='${FUEL_RELEASE}'" >> ${USER_HOME_DIR}/openrc
    echo "export CONTROLLER_HOST='${CONTROLLER_HOST}'" >> ${USER_HOME_DIR}/openrc
    echo "export COMPUTE_HOST='${COMPUTE_HOST}'" >> ${USER_HOME_DIR}/openrc
    echo "export OS_AUTH_URL='${OS_PUBLIC_AUTH_URL}'" >> ${USER_HOME_DIR}/openrc
    echo "export OS_PUBLIC_IP='${OS_PUBLIC_IP}'" >> ${USER_HOME_DIR}/openrc
    echo "export USER_NAME='${USER_NAME}'" >> ${USER_HOME_DIR}/openrc
    if [ "${TLS_ENABLED}" = "yes" ]; then
        scp ${CONTROLLER_HOST}:${REMOTE_CA_CERT} ${LOCAL_CA_CERT}
        echo "export OS_CACERT='${LOCAL_CA_CERT}'" >> ${USER_HOME_DIR}/openrc
    fi

    chown -R ${USER_NAME} ${USER_HOME_DIR}
}

setup_virtualenv() {
    message "Setup virtualenv in ${VIRTUALENV_DIR}"
    virtualenv -p python2.7 ${VIRTUALENV_DIR}
}

install_tempest() {
    message "Installing Tempest into ${DEST}"

    cd ${DEST}
    local tempest_dir="${DEST}/tempest"
    rm -rf ${tempest_dir}
    git clone git://git.openstack.org/openstack/tempest.git
    cd ${tempest_dir}
    if [ "${TEMPEST_COMMIT_ID}" != "master" ]; then
        git checkout ${TEMPEST_COMMIT_ID}
    fi

    ${VIRTUALENV_DIR}/bin/pip install -U -r ${tempest_dir}/requirements.txt
    message "Tempest has been installed into ${tempest_dir}"

    cp ${TOP_DIR}/tempest/configure_tempest.sh ${VIRTUALENV_DIR}/bin/configure_tempest
    cp ${TOP_DIR}/tempest/configure_shouldfail_file.sh ${VIRTUALENV_DIR}/bin/configure_shouldfail_file
    cp ${TOP_DIR}/tempest/run_tests.sh ${VIRTUALENV_DIR}/bin/run_tests
    cp -r ${TOP_DIR}/shouldfail ${DEST}
    mkdir -p ${TEMPEST_REPORTS_DIR}

    message "Downloading necessary resources for Tempest"
    local tempest_files="${VIRTUALENV_DIR}/files"
    rm -rf ${tempest_files}
    mkdir ${tempest_files}
    wget -O ${tempest_files}/cirros-${CIRROS_VERSION}-x86_64-uec.tar.gz ${CIRROS_UEC_IMAGE_URL}
    wget -O ${tempest_files}/cirros-${CIRROS_VERSION}-x86_64-disk.img ${CIRROS_DISK_IMAGE_URL}
    cd ${tempest_files}
    tar xzf cirros-${CIRROS_VERSION}-x86_64-uec.tar.gz

    chown -R ${USER_NAME} ${DEST}
}

install_helpers() {
    message "Installing helpers"
    cp ${TOP_DIR}/helpers/init_env_variables.sh ${VIRTUALENV_DIR}/bin/
    cp ${TOP_DIR}/helpers/subunit_shouldfail_filter.py ${VIRTUALENV_DIR}/bin/subunit-shouldfail-filter
    cp ${TOP_DIR}/helpers/subunit_html.py ${VIRTUALENV_DIR}/bin/subunit-html
    cp ${TOP_DIR}/helpers/colorizer.py ${VIRTUALENV_DIR}/bin/colorizer
    ${VIRTUALENV_DIR}/bin/pip install -U -r ${TOP_DIR}/requirements.txt
}

add_public_bind_to_keystone_haproxy_conf_for_admin_port() {
    # Keystone operations require admin endpoint which is internal and not
    # accessible from the Fuel master node. So we need to make Keystone admin
    # endpoint accessible from the Fuel master node. Before we do it, we need
    # to make haproxy listen to Keystone admin port 35357 on interface with public IP
    message "Add public bind to Keystone haproxy config for admin port on all controllers"
    if [ ! "$(ssh ${CONTROLLER_HOST} "grep ${OS_PUBLIC_IP}:35357 ${KEYSTONE_HAPROXY_CONFIG_PATH}")" ]; then
        local controller_hosts=$(fuel node "$@" | grep controller | awk -F\| '{print $5}' | sed -e s/[[:space:]]//g)
        local bind_string="  bind ${OS_PUBLIC_IP}:35357"
        if [ "${TLS_ENABLED}" = "yes" ]; then
            bind_string="  bind ${OS_PUBLIC_IP}:35357 ssl crt ${REMOTE_CA_CERT}"
        fi

        for controller_node in ${controller_hosts}; do
            ssh ${controller_node} "echo ${bind_string} >> ${KEYSTONE_HAPROXY_CONFIG_PATH}"
        done

        message "Restart haproxy"
        ssh ${CONTROLLER_HOST} "pcs resource disable p_haproxy --wait"
        ssh ${CONTROLLER_HOST} "pcs resource enable p_haproxy --wait"
    else
        message "Public bind already exists!"
    fi
}

add_dns_entry_for_tls () {
    message "Adding DNS entry for TLS"
    if [ "${TLS_ENABLED}" = "yes" ]; then
        local os_tls_hostname="$(echo ${OS_PUBLIC_AUTH_URL} | sed 's/https:\/\///;s|:.*||')"
        local dns_entry="$(grep "${OS_PUBLIC_IP} ${os_tls_hostname}" /etc/hosts)"
        if [ ! "${dns_entry}" ]; then
            echo "${OS_PUBLIC_IP} ${os_tls_hostname}" >> /etc/hosts
        else
            message "DNS entry for TLS is already added!"
        fi
    else
        message "TLS is not enabled. Nothing to do"
    fi
}

prepare_cloud() {
    # Keystone operations require admin endpoint which is internal and not
    # accessible from the Fuel master node. So we need to make all Keystone
    # endpoints accessible from the Fuel master node
    message "Make Keystone endpoints public"
    local identity_service_id="$(remote_cli "keystone service-list 2>/dev/null | grep identity | awk '{print \$2}'")"
    local internal_url="$(remote_cli "keystone endpoint-list 2>/dev/null | grep ${identity_service_id} | awk '{print \$8}'")"
    local admin_url="$(remote_cli "keystone endpoint-list 2>/dev/null | grep ${identity_service_id} | awk '{print \$10}'")"
    if [ "${admin_url}" = "${OS_PUBLIC_AUTH_URL/5000/35357}" ]; then
        message "Keystone endpoints already public!"
    else
        local old_endpoint="$(remote_cli "keystone endpoint-list 2>/dev/null | grep ${identity_service_id} | awk '{print \$2}'")"
        remote_cli "keystone endpoint-create --region RegionOne --service ${identity_service_id} --publicurl ${OS_PUBLIC_AUTH_URL} --adminurl ${OS_PUBLIC_AUTH_URL/5000/35357} --internalurl ${internal_url} 2>/dev/null"
        remote_cli "keystone endpoint-delete ${old_endpoint} 2>/dev/null"
    fi

    message "Create needed tenant and roles for Tempest tests"
    remote_cli "keystone tenant-create --name demo 2>/dev/null || true"
    remote_cli "keystone user-create --tenant demo --name demo --pass demo 2>/dev/null || true"

    remote_cli "keystone role-create --name SwiftOperator 2>/dev/null || true"
    remote_cli "keystone role-create --name anotherrole 2>/dev/null || true"
    remote_cli "keystone role-create --name heat_stack_user 2>/dev/null || true"
    remote_cli "keystone role-create --name heat_stack_owner 2>/dev/null || true"
    remote_cli "keystone role-create --name ResellerAdmin 2>/dev/null || true"

    remote_cli "keystone user-role-add --role SwiftOperator --user demo --tenant demo 2>/dev/null || true"
    remote_cli "keystone user-role-add --role anotherrole --user demo --tenant demo 2>/dev/null || true"
    remote_cli "keystone user-role-add --role admin --user admin --tenant demo 2>/dev/null || true"

    message "Create flavor 'm1.tempest-nano' for Tempest tests"
    remote_cli "nova flavor-create m1.tempest-nano 0 64 0 1 2>/dev/null || true"
    message "Create flavor 'm1.tempest-micro' for Tempest tests"
    remote_cli "nova flavor-create m1.tempest-micro 42 128 0 1 2>/dev/null || true"

    message "Upload CirrOS image for Tempest tests"
    local cirros_image="$(remote_cli "glance image-list 2>/dev/null | grep cirros-${CIRROS_VERSION}-x86_64")"
    if [ ! "${cirros_image}" ]; then
        scp ${VIRTUALENV_DIR}/files/cirros-${CIRROS_VERSION}-x86_64-disk.img ${CONTROLLER_HOST}:/tmp/
        if [ $(echo $FUEL_RELEASE | awk -F'.' '{print $1}') -ge "8" ]; then
            remote_cli "glance image-create --name cirros-${CIRROS_VERSION}-x86_64 --file /tmp/cirros-${CIRROS_VERSION}-x86_64-disk.img --disk-format qcow2 --container-format bare --visibility public --progress 2>/dev/null || true"
        else
            remote_cli "glance image-create --name cirros-${CIRROS_VERSION}-x86_64 --file /tmp/cirros-${CIRROS_VERSION}-x86_64-disk.img --disk-format qcow2 --container-format bare --is-public=true --progress 2>/dev/null || true"
        fi
    else
        message "CirrOS image for Tempest tests already uploaded!"
    fi
}

main() {
    install_system_requirements
    install_python27_pip_virtualenv
    init_cluster_variables "$@"
    configure_env
    setup_virtualenv
    install_tempest
    install_helpers
    add_public_bind_to_keystone_haproxy_conf_for_admin_port "$@"
    add_dns_entry_for_tls
    prepare_cloud
}

main "$@"
