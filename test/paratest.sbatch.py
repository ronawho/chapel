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

def create_batch_file(test_dirs):
    process_template = os.path.join(chpl_home, 'util', 'build_configs', 'cray-internal', 'process-template.py')
    keys_len = "TEST_ARR_LEN={}".format(len(test_dirs)-1)
    keys_arr = "TEST_ARR={}".format(' '.join(test_dirs))
    subprocess.check_output([process_template, '--template', 'paratest.batch.template', '--output', 'paratest.batch', keys_len, keys_arr])

def run_batch_file():
    print(subprocess.check_output(['sbatch', '--wait', 'paratest.batch']))

test_dirs = fileutils.find_chpl_test_dirs(sys.argv[1])
create_batch_file(test_dirs)

os.environ['CHPL_TEST_LIMIT_RUNNING_EXECUTABLES'] = 'yes'
os.environ['CHPL_RT_OVERSUBSCRIBED'] = 'yes'
run_batch_file()

input_files = ['start_test_log_{}'.format(i) for i in range(len(test_dirs))]
output_file = 'paratest.log'
fileutils.merge_files(input_files, output_file)

print(summarize.create_summary(output_file))
