#!/usr/bin/env python

# Copyright 2014: Mirantis Inc.
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

import optparse
import sys

from subunit import v2 as subunit_v2
from subunit.v2 import ByteStreamToStreamResult
from testtools import StreamResult
import yaml


def make_options():
    parser = optparse.OptionParser(description=__doc__)
    parser.add_option(
        "--shouldfail-file",
        type=str,
        help="File with list of test ids that are expected to fail; "
             "on failure their result will be changed to xfail; on success "
             "they will be changed to error.",
        dest="shouldfail_file",
        action="append")
    return parser


class ProcessedStreamResult(StreamResult):
    def __init__(self, output, shouldfail):
        self.output = output
        self.shouldfail = shouldfail

    def startTestRun(self):
        self.output.startTestRun()

    def stopTestRun(self):
        self.output.stopTestRun()

    def status(self, test_id=None, test_status=None, test_tags=None,
               runnable=True, file_name=None, file_bytes=None, eof=False,
               mime_type=None, route_code=None, timestamp=None):

        if ((test_status in ['fail', 'success', 'xfail', 'uxsuccess', 'skip'])
                and (test_id in self.shouldfail)):
            if test_status == 'fail':
                test_status = 'xfail'
            elif test_status == 'success':
                test_status = 'uxsuccess'

            if self.shouldfail[test_id]:
                self.output.status(test_id=test_id,
                                   test_tags=test_tags,
                                   file_name='shouldfail-info',
                                   mime_type='text/plain; charset="utf8"',
                                   file_bytes=self.shouldfail[test_id],
                                   route_code=route_code,
                                   timestamp=timestamp)

        self.output.status(test_id=test_id, test_status=test_status,
                           test_tags=test_tags, runnable=runnable,
                           file_name=file_name, file_bytes=file_bytes,
                           mime_type=mime_type, route_code=route_code,
                           timestamp=timestamp)


def read_shouldfail_file(options):
    shouldfail = {}

    for path in options.shouldfail_file or ():
        f = open(path, 'rb')
        try:
            content = yaml.safe_load(f)
            for item in content:
                if not isinstance(item, dict):
                    shouldfail[item] = None
                else:
                    shouldfail.update(item)
        finally:
            f.close()

    return shouldfail


def main():
    parser = make_options()
    (options, args) = parser.parse_args()

    output = subunit_v2.StreamResultToBytes(sys.stdout)
    shouldfail = read_shouldfail_file(options)

    result = ProcessedStreamResult(output, shouldfail)
    converter = ByteStreamToStreamResult(source=sys.stdin,
                                         non_subunit_name='process-stderr')
    result.startTestRun()
    converter.run(result)
    result.stopTestRun()


if __name__ == '__main__':
    main()
