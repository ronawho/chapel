import os
import subprocess
import shutil

chpl_home = os.getenv('CHPL_HOME')

# get_chplenv is used to speedup `testEnv` by avoiding repeat calls to
# printchplenv. TODO this was taken from sub_test, so put in helper
def get_chplenv():
    env_cmd = [os.path.join(chpl_home, 'util', 'printchplenv'), '--all', '--simple', '--no-tidy', '--internal']
    chpl_env = subprocess.check_output(env_cmd).decode()
    chpl_env = dict(map(lambda l: l.split('=', 1), chpl_env.splitlines()))
    return chpl_env

os.environ['CHPL_TEST_VGRND_EXE'] = 'off'
os.environ['CHPLENV_IN_ENV'] = 'true'
chpl_env = get_chplenv()
file_env = os.environ.copy()
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
def find_chpl_test_dirs(dirname):
    test_dirs = sorted(fast_scandir(dirname))
    return test_dirs
