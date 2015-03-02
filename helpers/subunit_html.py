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

import cgi
import collections
import sys
import uuid

import subunit.v2
import testtools


HTML_TEMPLATE = """
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" dir="ltr" lang="en-US">
<head>
    <title>Test Report</title>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>

    <style type="text/css" media="screen">
        body { font-family: sans-serif; font-size: 10pt; }
        a { text-decoration: none; }
        tfoot, thead { background-color: #ccc; font-weight: bold; }
        tbody td { padding-left: 5px !important; }
        .number { text-align: center; }
        .info_header { font-weight: bold; margin-left: 2em; margin-top: 1em;
                color: black; }
        .info_content { white-space: pre-wrap; color: black;
                margin-left: 2em; margin-top: 0.5em; font-family: monospace; }
        .test_class_status_success  { background-color: #6c6 !important; }
        .test_class_status_fail     { background-color: #c60 !important; }
        .test_class_status_error    { background-color: #c00 !important; }
        .test_class_status_skip     { background-color: #59f !important; }
        .test_status_success       { color: #6c6 !important; }
        .test_status_fail          { color: #c60 !important; }
        .test_status_error         { color: #c00 !important; }
        .test_status_skip          { color: #006 !important; }
        .test_status_xfail         { color: #6c6 !important; }
        .test_status_uxsuccess     { color: #c66 !important; }
        .parent_success   { display: none; }
        .parent_skip      { display: none; }
        .test_class_row   { cursor: pointer; }
        .test_name        { margin-left: 2em; }
    </style>
    <script type="text/javascript" src="https://code.jquery.com/jquery-2.1.1.min.js"></script>
    <script type="text/javascript" src="https://cdn.datatables.net/1.10.2/js/jquery.dataTables.min.js"></script>
    <link rel=stylesheet type=text/css href="https://cdn.datatables.net/1.10.2/css/jquery.dataTables.min.css">

    <script type="text/javascript">
        $(document).ready(function () {
            $(".expand_button").click(function(event) {
                event.preventDefault();
                event.stopPropagation();
                $("#info_" + this.id).toggle();
            });
            $(".test_class_row").click(function(event) {
                event.preventDefault();
                event.stopPropagation();
                $("." + this.id + "_child").toggle();
            });
            $("#report").dataTable({
                "autoWidth": false,
                "paging":   false,
                "ordering": false,
                "info":     false,
                "columnDefs": [
                    { className: "number", "targets": [2, 3, 4, 5, 6, 7, 8] }
                ]
            });
        });
    </script>
    </head>
<body>

<h1>Test Report</h1>

%(summary_html)s
%(report_html)s

</body>
</html>
"""  # noqa

SUMMARY_TEMPLATE = """
    <div>Summary: %(summary)s</div>
"""

REPORT_TEMPLATE = """
<table id="report" class="display compact">
    <thead>
        <tr id='header_row'>
            <td>Test Group/Test case</td>
            <td>Status</td>
            <td>Count</td>
            <td>Success</td>
            <td>Failure</td>
            <td>Error</td>
            <td>Expected&nbsp;Failure</td>
            <td>Unexpected&nbsp;Success</td>
            <td>Skip</td>
        </tr>
    </thead>
    <tbody>
        %(rows_html)s
    </tbody>
    <tfoot>
        <tr id='total_row'>
            <td>Total</td>
            <td>%(status_text)s</td>
            <td>%(count)s</td>
            <td>%(success)s</td>
            <td>%(fail)s</td>
            <td>%(error)s</td>
            <td>%(xfail)s</td>
            <td>%(uxsuccess)s</td>
            <td>%(skip)s</td>
        </tr>
    </tfoot>
</table>
"""

REPORT_CLASS_TEMPLATE = """
<tr class="test_class_status_%(test_class_status)s test_class_row" id="%(test_class_id_s)s">
    <td class="test_class">%(test_class)s</td>
    <td>%(test_class_status_text)s</td>
    <td>%(count)s</td>
    <td>%(success)s</td>
    <td>%(fail)s</td>
    <td>%(error)s</td>
    <td>%(xfail)s</td>
    <td>%(uxsuccess)s</td>
    <td>%(skip)s</td>
</tr>
"""   # noqa

REPORT_TEST_TEMPLATE = """
<tr class="test_status_%(test_status)s %(test_class_id_s)s_child parent_%(test_class_status)s">
    <td><div class="test_name">
        <a href="#" class="expand_button" id="%(test_id_s)s">%(test_name)s</a></div>
        <div id="info_%(test_id_s)s" style="display: none;">%(info)s</div>
    </td>
    <td><div>%(test_status_text)s</div></td>
    <td></td><td></td><td></td><td></td><td></td><td></td><td></td>
</tr>
"""  # noqa

INFO_TEMPLATE = """
    <div class="info_header">%(file_name)s</div>
    <div class="info_content">%(content)s</div>
"""

INFO_TEMPLATE_EMPTY = """
    <div class="info_content">No details available</div>
"""

STATUS_TEXT = {
    '': 'unknown',
    'success': 'success',
    'fail': 'failure',
    'error': 'error',
    'xfail': 'expected&nbsp;failure',
    'uxsuccess': 'unexpected&nbsp;success',
    'skip': 'skip'
}


def make_summary(counters):
    result = []
    for status, value in counters.items():
        if value:
            result.append(STATUS_TEXT[status] + ' &mdash; %d' % value)
    if result:
        return ', '.join(result)
    else:
        'No tests found'


def split_test_id(test_id):
    test_id_split = test_id.rsplit('.', 1)
    if len(test_id_split) > 1:
        test_class, test_name = test_id_split
    else:
        test_class = ''
        test_name = test_id

    return test_class, test_name


def calc_summary_status(statuses):
    test_class_status = 'success'
    if statuses['error']:
        test_class_status = 'error'
    elif statuses['fail'] or statuses['uxsuccess']:
        test_class_status = 'fail'
    elif statuses['skip'] == sum([statuses[s] for s in STATUS_TEXT.keys()]):
        test_class_status = 'skip'
    return test_class_status


def make_report(results):
    data = collections.defaultdict(dict)
    for test_class, test_name in results.keys():
        data[test_class][test_name] = results[(test_class, test_name)]

    rows_html = []
    summary = collections.defaultdict(int)

    for test_class in sorted(data.keys()):

        test_html = []
        statuses = collections.defaultdict(int)
        test_class_id_s = uuid.uuid4()

        for test_name, value in data[test_class].items():
            statuses[value.status] += 1
            summary[value.status] += 1

        test_class_status = calc_summary_status(statuses)

        for test_name, value in data[test_class].items():
            info = []
            for v in sorted(value.info, key=lambda x: x.name):
                info.append(INFO_TEMPLATE % dict(
                    file_name=v.name,
                    content=cgi.escape(v.content),
                ))
            if not info:
                info.append(INFO_TEMPLATE_EMPTY)

            test_html.append(REPORT_TEST_TEMPLATE % dict(
                test_id=test_class + '.' + test_name,
                test_id_s=uuid.uuid4(),
                test_class_id_s=test_class_id_s,
                test_class_status=test_class_status,
                test_name=test_name,
                test_status=value.status,
                test_status_text=STATUS_TEXT[value.status],
                info='\n'.join(info),
            ))

        class_html = REPORT_CLASS_TEMPLATE % dict(
            test_class=test_class,
            test_class_id_s=test_class_id_s,
            test_class_status=test_class_status,
            test_class_status_text=STATUS_TEXT[test_class_status],
            status=test_class_status,
            count=sum(statuses.values()),
            success=statuses['success'],
            fail=statuses['fail'],
            error=statuses['error'],
            skip=statuses['skip'],
            xfail=statuses['xfail'],
            uxsuccess=statuses['uxsuccess'],
        )

        rows_html.append(class_html)
        rows_html.extend(test_html)

    report_html = REPORT_TEMPLATE % dict(
        rows_html='\n'.join(rows_html),
        status=calc_summary_status(summary),
        status_text=STATUS_TEXT[calc_summary_status(summary)],
        count=sum(summary.values()),
        success=summary['success'],
        fail=summary['fail'],
        error=summary['error'],
        skip=summary['skip'],
        xfail=summary['xfail'],
        uxsuccess=summary['uxsuccess'],
    )

    summary_html = SUMMARY_TEMPLATE % dict(
        summary=make_summary(summary)
    )

    return HTML_TEMPLATE % dict(
        summary_html=summary_html,
        report_html=report_html,
    )


FileItem = collections.namedtuple('FileItem', ['name', 'content'])


class Record(object):
    def __init__(self):
        self.status = ''
        self.info = list()
        self.start = None
        self.end = None


class ProcessedStreamResult(testtools.StreamResult):
    """Output test results in html."""

    def __init__(self, output):
        super(ProcessedStreamResult, self).__init__()
        self.output = output

        self.results = collections.defaultdict(Record)

    def status(self, test_id=None, test_status=None, test_tags=None,
               runnable=True, file_name=None, file_bytes=None, eof=False,
               mime_type=None, route_code=None, timestamp=None):

        if not test_id:
            return  # ignore unknown

        test_class_name = split_test_id(test_id)

        if file_name and file_bytes:
            self.results[test_class_name].info.append(
                FileItem(file_name, file_bytes))

        if test_status in STATUS_TEXT.keys():
            self.results[test_class_name].status = test_status
            self.results[test_class_name].end = timestamp

        if test_status == 'inprogress':
            self.results[test_class_name].start = timestamp

        if timestamp:
            self.results[test_class_name].timestamp = timestamp

    def stopTestRun(self):
        body = make_report(self.results)
        self.output.write(body.encode('utf8'))


def main():
    result = ProcessedStreamResult(sys.stdout)

    converter = subunit.v2.ByteStreamToStreamResult(
        source=sys.stdin, non_subunit_name='process-stderr')
    result.startTestRun()
    converter.run(result)
    result.stopTestRun()


if __name__ == '__main__':
    main()
