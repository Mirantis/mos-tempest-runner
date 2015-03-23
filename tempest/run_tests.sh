#!/bin/bash

TOP_DIR=$(cd $(dirname "$0") && pwd)
source ${TOP_DIR}/init_env_variables.sh

SERIAL="${SERIAL:-false}"

display_help() {
    echo "This script runs Tempest tests"
    echo "Usage: ${0##*/} [-h] [<testr-arguments>]"
    echo -e "\nOptions:"
    echo "      -h                   Display help"
    echo -e "\nArguments:"
    echo "      <testr-arguments>    Arguments that are passed to testr"
    echo -e "\nExamples:"
    echo "      run_tests"
    echo "      run_tests tempest.api.identity"
    echo "      run_tests tempest.api.identity.admin.test_users.UsersTestJSON"
    echo "      run_tests tempest.api.identity.admin.test_tokens.TokensTestJSON.test_create_get_delete_token"
}

parse_arguments() {
    while getopts ":h" opt; do
        case ${opt} in
            h)
                display_help
                exit 0
                ;;
            *)
                error "An invalid option has been detected"
                display_help
                exit 1
        esac
    done
    shift $((OPTIND-1))
    [ "$1" = "--" ] && shift
    TESTARGS="$@"
}

choose_shouldfail_file() {
    # Define the default file
    SHOULDFAIL_FILE="${DEST}/shouldfail/default_shouldfail.yaml"

    local fuel_release="$(echo ${FUEL_RELEASE} | sed "s/'//g" | sed "s/\./_/g")"
    local shouldfail_file="${DEST}/shouldfail/${fuel_release}/shouldfail.yaml"
    if [ -f ${shouldfail_file} ]; then
        SHOULDFAIL_FILE=${shouldfail_file}

        local is_radosgw="$(ssh ${CONTROLLER_HOST} "cat /etc/ceph/ceph.conf | grep -o radosgw.gateway" 2>/dev/null)"
        if [ ${is_radosgw} ]; then
            SHOULDFAIL_FILE="${shouldfail_file/shouldfail/shouldfail_radosgw}"
        fi
    fi

    message "Shouldfail:"
    cat ${SHOULDFAIL_FILE}
}

run_tests() {
    if [ ! -d .testrepository ]; then
        testr init
    fi

    find . -type f -name "*.pyc" -delete
    export OS_TEST_PATH=./tempest/test_discover

    SUBUNIT_STREAM=$(cat .testrepository/next-stream)

    local testr_params="--parallel"
    if [ "${SERIAL}" = "true" ]; then
        testr_params=""
    fi
    choose_shouldfail_file
    testr run ${testr_params} --subunit ${TESTARGS} | subunit-1to2 | ${TOP_DIR}/subunit-shouldfail-filter --shouldfail-file=${SHOULDFAIL_FILE} | subunit-2to1 | ${TOP_DIR}/colorizer
}

collect_results() {
    if [ -f .testrepository/${SUBUNIT_STREAM} ] ; then
        local subunit="$(mktemp)"
        subunit-1to2 < .testrepository/${SUBUNIT_STREAM} | ${TOP_DIR}/subunit-shouldfail-filter --shouldfail-file=${SHOULDFAIL_FILE} > ${subunit}
        ${TOP_DIR}/subunit-html < ${subunit} > ${TEMPEST_REPORTS_DIR}/tempest-report.html
        subunit2junitxml < ${subunit} > ${TEMPEST_REPORTS_DIR}/tempest-report.xml
        cp ${DEST}/tempest/etc/tempest.conf ${TEMPEST_REPORTS_DIR}/
        cat ${SHOULDFAIL_FILE} > ${TEMPEST_REPORTS_DIR}/shouldfail.yaml
    else
        error "Subunit stream ${SUBUNIT_STREAM} is not found"
    fi
}

run() {
    message "Running Tempest tests"
    cd ${DEST}/tempest
    configure_tempest
    run_tests
    collect_results
    cd ${TOP_DIR}
}

return_exit_code() {
    local failures_count="$(cat ${TEMPEST_REPORTS_DIR}/tempest-report.xml | grep "failures" | awk -F '"' '{print $4}')"
    if [ ${failures_count} -eq "0" ]; then
        exit 0
    else
        exit 1
    fi
}

main() {
    parse_arguments "$@"
    run
    return_exit_code
}

main "$@"
