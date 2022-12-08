#!/usr/bin/env python3

"""
paratest alternative that uses sbatch job arrays instead of manually ssh'ing
and distributing work. Relies on large slurm MaxArraySize so submit all dirs
and SelectTypeParameters=CR_LLN to load balance
"""

import os
import sys
import subprocess

import summarize
import fileutils

chpl_home = os.getenv('CHPL_HOME')

def create_batch_file(test_dirs):
    process_template = os.path.join(chpl_home, 'util', 'build_configs', 'cray-internal', 'process-template.py')
    keys_start = "START={}".format(0)
    keys_len = "TEST_ARR_LEN={}".format(len(test_dirs)-1)
    keys_arr = "TEST_ARR={}".format(' '.join('"{}"'.format(test_dir) for test_dir in test_dirs))
    subprocess.check_output([process_template, '--template', 'paratest.batch.template', '--output', 'paratest.batch', keys_start, keys_len, keys_arr])

def run_batch_file(test_dirs, wait=True):
    args = ['sbatch', '--parsable']
    if wait: 
        args.append('--wait')
    args.append('paratest.batch')
    print(args)
    if wait:
        subprocess.run(args)
    else:
        out = subprocess.check_output(args).decode().strip()
        return out

output_file = 'paratest.log'
test_dirs = fileutils.find_chpl_test_dirs(sys.argv[1], output_file)

print(test_dirs[0:100])

os.environ['CHPL_TEST_LIMIT_RUNNING_EXECUTABLES'] = 'yes'
os.environ['CHPL_RT_OVERSUBSCRIBED'] = 'yes'

create_batch_file(test_dirs)
run_batch_file(test_dirs)
# TODO can we report progress, maybe with `squeue --job 30498 --array --noheader --states=PENDING,RUNNING`

# TODO move this into an sbatch call that has a dep on submission
input_files = ['start_test_log_{}'.format(i) for i in range(len(test_dirs))]
fileutils.merge_files(input_files, output_file)

print(summarize.create_summary(output_file))
