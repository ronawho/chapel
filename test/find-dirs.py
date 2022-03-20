import os
import sys
import subprocess

chpl_home = os.getenv('CHPL_HOME')

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
            skipif = dirname + '.skipif'
            if os.path.exists(skipif):
                testEnv = os.path.join(chpl_home, 'util', 'test', 'testEnv')
                out = subprocess.check_output([testEnv, skipif], env=file_env).decode().strip()
                if out in ('1', 'True'):
                    continue
            chpl_subfolders.extend(fast_scandir(dirname))
        return chpl_subfolders

for d in sorted(fast_scandir(sys.argv[1])):
    print(d)
