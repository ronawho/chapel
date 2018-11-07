#!/usr/bin/env python

import os
import sys

chpl_home = os.getenv('CHPL_HOME')
chplenv_dir = os.path.join(chpl_home, 'util', 'chplenv')
sys.path.insert(0, os.path.abspath(chplenv_dir))

import chpl_home_utils
import chpl_3p_jemalloc_configs

def get():
    third_party = chpl_home_utils.get_chpl_third_party()
    uniq_cfg_path = chpl_3p_jemalloc_configs.get_uniq_cfg_path()
    install_dir = os.path.join(third_party, 'jemalloc', 'install', uniq_cfg_path)
    return install_dir


def _main():
    install_dir = get()
    sys.stdout.write("{0}\n".format(install_dir))


if __name__ == '__main__':
    _main()
