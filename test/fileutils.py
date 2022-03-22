import os
import subprocess
import shutil
import sys
import re

chpl_home = os.getenv('CHPL_HOME')

# get_chplenv is used to speedup `testEnv` by avoiding repeat calls to
# printchplenv. TODO this was taken from sub_test, so put in helper
def get_chplenv():
    env_cmd = [os.path.join(chpl_home, 'util', 'printchplenv'), '--all', '--simple', '--no-tidy', '--internal']
    chpl_env = subprocess.check_output(env_cmd).decode()
    chpl_env = dict(map(lambda l: l.split('=', 1), chpl_env.splitlines()))
    return chpl_env

chpl_env = get_chplenv()
file_env = os.environ.copy()
file_env['CHPL_TEST_VGRND_EXE'] = 'off'
file_env['CHPLENV_IN_ENV'] = 'true'
file_env.update(chpl_env)

def skipif(skipif_file):
    testEnv = os.path.join(chpl_home, 'util', 'test', 'testEnv')
    out = subprocess.check_output([testEnv, skipif_file], env=file_env).decode().strip()
    return out in ('1', 'True')



def merge_files(intput_files, output_file):
    with open(output_file, 'wb') as out_file:
        for input_file in intput_files:
            with open(input_file, 'rb') as in_file:
                shutil.copyfileobj(in_file, out_file)

def has_chpl_files(dirname):
    with os.scandir(dirname) as it:
        contains = False
        for f in it:
            if f.is_file():
                if f.name == 'NOTEST':
                    return False
            if f.name.endswith(('.chpl', 'test.c', 'ml-test.c', 'sub_test')):
                contains=True
    return contains

def fast_scandir(dirname):
    with os.scandir(dirname) as it:
        chpl_subfolders = []
        if has_chpl_files(dirname):
            chpl_subfolders.extend([dirname])
        subfolders = [f.path for f in it if f.is_dir()]
        for dirname in list(subfolders):
            if os.path.exists(dirname + '.notest'):
                continue
            skipif_file = dirname + '.skipif'
            if os.path.exists(skipif_file):
                if skipif(skipif_file):
                    continue
            chpl_subfolders.extend(fast_scandir(dirname))
        return chpl_subfolders

# TODO instead of just sorting, look through old logfiles for long running or
# estimate based on number and size of .chpl files
def find_chpl_test_dirs(dirname, logfile):
    try:
        with open(logfile, 'r') as f:
            reg = re.compile('\[Finished subtest "(.*)" - (.*) seconds')
            lines = [line.strip() for line in f if reg.match(line)]
            res = {m.group(1): float(m.group(2)) for l in lines for m in [reg.match(l)] if m}
    except FileNotFoundError:
        res = {}
        pass

    test_dirs = fast_scandir(dirname)
    test_dirs = [(res.get(td.lstrip('./'), 10000.0), td) for td in test_dirs]
    test_dirs.sort(reverse=True)
    test_dirs = [td[1] for td in test_dirs]
    return test_dirs

if __name__ == '__main__':
    dirname = sys.argv[1] if len(sys.argv) > 1 else '.'
    logfile = sys.argv[2] if len(sys.argv) > 2 else ''
    print(' '.join(find_chpl_test_dirs(dirname, logfile)))
