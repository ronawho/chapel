#!/usr/bin/env python3

"""
paratest alternative that uses sbatch job arrays instead of manually ssh'ing
and distributing work
"""

import os
import sys
import subprocess

import summarize
import fileutils

chpl_home = os.getenv('CHPL_HOME')

def create_batch_file(test_dirs, start):
    process_template = os.path.join(chpl_home, 'util', 'build_configs', 'cray-internal', 'process-template.py')
    keys_start = "START={}".format(start)
    keys_len = "TEST_ARR_LEN={}".format(len(test_dirs)-1)
    keys_arr = "TEST_ARR={}".format(' '.join('"{}"'.format(test_dir) for test_dir in test_dirs))
    subprocess.check_output([process_template, '--template', 'paratest.batch.template', '--output', 'paratest.batch', keys_start, keys_len, keys_arr])

def chunks(l, n):
    n = max(1, n)
    return (l[i:i+n] for i in range(0, len(l), n))

def run_batch_file(test_dirs, deps=False):
    args = ['sbatch', '--parsable']
    if deps:
        args.append('--wait')
        args.append('--dependency')
        args.append(','.join(deps))
    args.append('paratest.batch')
    print(args)
    out = subprocess.check_output(args).decode().strip()
    return out


output_file = 'paratest.log'
test_dirs = fileutils.find_chpl_test_dirs(sys.argv[1], output_file)

print(test_dirs[0:100])

os.environ['CHPL_TEST_LIMIT_RUNNING_EXECUTABLES'] = 'yes'
os.environ['CHPL_RT_OVERSUBSCRIBED'] = 'yes'

deps = []
start = 0
for test_dirs2 in chunks(test_dirs[:-1], 1000):
    create_batch_file(test_dirs2, start)
    deps.append(run_batch_file(test_dirs2))
    start += len(test_dirs2)
create_batch_file([test_dirs[-1]], start)
run_batch_file([test_dirs[-1]], deps)


input_files = ['start_test_log_{}'.format(i) for i in range(len(test_dirs))]
fileutils.merge_files(input_files, output_file)

print(summarize.create_summary(output_file))
