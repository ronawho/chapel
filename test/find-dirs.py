import os
import sys
import subprocess

def get_chplenv():
    env_cmd = [os.path.join('/Users/eronagha/chapel/util', 'printchplenv'), '--all', '--simple', '--no-tidy', '--internal']
    chpl_env = subprocess.check_output(env_cmd).decode()
    chpl_env = dict(map(lambda l: l.split('=', 1), chpl_env.splitlines()))
    return chpl_env

os.environ['CHPL_TEST_VGRND_EXE'] = 'off'
os.environ['CHPLENV_IN_ENV'] = 'true'

chpl_env = get_chplenv()
file_env = os.environ.copy()
file_env.update(chpl_env)

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

def fast_scandir2(dirname):
    with os.scandir(dirname) as it:
        chpl_subfolders = []
        if has_chpl_files(dirname):
            chpl_subfolders.extend([dirname])
        subfolders = [f.path for f in it if f.is_dir()]
        for dirname in list(subfolders):
            if os.path.exists(dirname + '.notest'):
                continue
            skipif = dirname + '.skipif'
            if os.path.exists(skipif):
                testEnv = '/Users/eronagha/chapel/util/test/testEnv'
                out = subprocess.check_output([testEnv, skipif], env=file_env).decode().strip()
                if out in ('1', 'True'):
                    continue
            ret = fast_scandir2(dirname)
            subfolders.extend(ret[0])
            chpl_subfolders.extend(ret[1])
        return (subfolders, chpl_subfolders)

def fast_scandir(dirname):
    subfolders= [f.path for f in os.scandir(dirname) if f.is_dir()]
    for dirname in list(subfolders):
        subfolders.extend(fast_scandir(dirname))
    return subfolders



for d in sorted(fast_scandir2(sys.argv[1])[1]):
    print(d)
