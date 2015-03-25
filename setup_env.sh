#!/bin/bash -xe

TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/helpers/init_env_variables.sh

install_system_requirements() {
    message "Enabling default CentOS repo"
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

        message "Installing pip and virtualenv for Python 2.7"
        local get_pip_file="$(mktemp)"
        wget -O ${get_pip_file} ${PIP_LOCATION}
        python2.7 ${get_pip_file}
        pip2.7 install -U tox
    fi
}

init_cluster_variables() {
    message "Initialize cluster variables"

    local controller_host_id="$(fuel node | grep controller | awk '{print $1}' | head -1)"
    CONTROLLER_HOST="node-${controller_host_id}"
    message "Controller host is '${CONTROLLER_HOST}'"

    FUEL_RELEASE="$(fuel --fuel-version 2>&1 | grep -e ^release: | awk '{print $2}')"
    message "Fuel release is ${FUEL_RELEASE}"

    OS_AUTH_URL="$(ssh root@${CONTROLLER_HOST} ". openrc; keystone catalog --service identity | grep publicURL | awk '{print \$4}'")"
    OS_AUTH_IP="$(echo "${OS_AUTH_URL}" | grep -Eo '([0-9]{1,3}[\.]){3}[0-9]{1,3}')"
    message "OS_AUTH_URL = ${OS_AUTH_URL}"
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
    echo "export FUEL_RELEASE='${FUEL_RELEASE}'" >> ${USER_HOME_DIR}/openrc
    echo "export CONTROLLER_HOST='${CONTROLLER_HOST}'" >> ${USER_HOME_DIR}/openrc
    echo "export OS_AUTH_URL='${OS_AUTH_URL}'" >> ${USER_HOME_DIR}/openrc
    echo "export USER_NAME='${USER_NAME}'" >> ${USER_HOME_DIR}/openrc

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
    ${VIRTUALENV_DIR}/bin/python setup.py install
    # TODO (ylobankov): don't use the workaround when bug #1410622 is fixed.
    # This is the workaround to avoid failures for EC2 tests. According to
    # the bug #1408987 reported to Nova these tests permanently fail since
    # the boto 2.35.0 has been released. The bug #1408987 was fixed and
    # backported to the Juno release. However the issue has not been completely
    # resolved. The corresponding bug #1410622 was reported to Nova and was
    # fixed only for Kilo.
    ${VIRTUALENV_DIR}/bin/pip install boto==2.34.0
    message "Tempest has been installed into ${tempest_dir}"

    cp ${TOP_DIR}/tempest/configure_tempest.sh ${VIRTUALENV_DIR}/bin/configure_tempest
    cp ${TOP_DIR}/tempest/run_tests.sh ${VIRTUALENV_DIR}/bin/run_tests
    cp -r ${TOP_DIR}/shouldfail ${DEST}
    mkdir -p ${TEMPEST_REPORTS_DIR}

    message "Downloading necessary resources for Tempest"
    local tempest_files="${VIRTUALENV_DIR}/files"
    rm -rf ${tempest_files}
    mkdir ${tempest_files}
    wget -O ${tempest_files}/cirros-${CIRROS_VERSION}-x86_64-uec.tar.gz ${CIRROS_IMAGE_URL}
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

add_public_bind_to_keystone_haproxy_conf() {
    # Keystone operations require admin endpoint which is internal and not
    # accessible from the Fuel master node. So we need to make all Keystone
    # endpoints accessible from the Fuel master node. Before we do it, we need
    # to make haproxy listen to Keystone admin port 35357 on interface with public IP
    if [ ! "$(ssh root@${CONTROLLER_HOST} "grep ${OS_AUTH_IP}:35357 ${KEYSTONE_HAPROXY_CONFIG_PATH}")" ]; then
        message "Add public bind to Keystone haproxy config for admin port on all controllers"
        local controller_node_ids=$(fuel node | grep controller | awk '{print $1}')
        for controller_node_id in ${controller_node_ids}; do
            ssh root@node-${controller_node_id} "echo '  bind ${OS_AUTH_IP}:35357' >> ${KEYSTONE_HAPROXY_CONFIG_PATH}"
        done

        message "Restart haproxy"
        ssh root@${CONTROLLER_HOST} "pcs resource disable p_haproxy --wait"
        ssh root@${CONTROLLER_HOST} "pcs resource enable p_haproxy --wait"
    fi
}

prepare_cloud() {
    source ${VIRTUALENV_DIR}/bin/activate
    source ${USER_HOME_DIR}/openrc

    # Keystone operations require admin endpoint which is internal and not
    # accessible from the Fuel master node. So we need to make all Keystone
    # endpoints accessible from the Fuel master node
    message "Make Keystone endpoints public"
    local identity_service_id="$(ssh ${CONTROLLER_HOST} ". openrc; keystone service-list | grep identity | awk '{print \$2}'")"
    local old_endpoint="$(ssh ${CONTROLLER_HOST} ". openrc; keystone endpoint-list | grep ${identity_service_id} | awk '{print \$2}'")"
    ssh ${CONTROLLER_HOST} ". openrc; keystone endpoint-create --region RegionOne --service ${identity_service_id} --publicurl ${OS_AUTH_URL} --adminurl ${OS_AUTH_URL/5000/35357} --internalurl ${OS_AUTH_URL}"
    ssh ${CONTROLLER_HOST} ". openrc; keystone endpoint-delete ${old_endpoint}"

    message "Create needed tenant and roles for Tempest tests"
    keystone tenant-create --name demo || true
    keystone user-create --tenant demo --name demo --pass demo || true

    keystone role-create --name SwiftOperator || true
    keystone role-create --name anotherrole || true
    keystone role-create --name heat_stack_user || true
    keystone role-create --name heat_stack_owner || true
    keystone role-create --name ResellerAdmin || true

    keystone user-role-add --role SwiftOperator --user demo --tenant demo || true
    keystone user-role-add --role anotherrole --user demo --tenant demo || true
    keystone user-role-add --role admin --user admin --tenant demo || true

    message "Create flavor 'm1.tempest-nano' for Tempest tests"
    nova flavor-create m1.tempest-nano 0 64 0 1 || true
    message "Create flavor 'm1.tempest-micro' for Tempest tests"
    nova flavor-create m1.tempest-micro 42 128 0 1 || true
}

main() {
    install_system_requirements
    install_python27_pip_virtualenv
    init_cluster_variables
    configure_env
    setup_virtualenv
    install_tempest
    install_helpers
    add_public_bind_to_keystone_haproxy_conf
    prepare_cloud
}

main
