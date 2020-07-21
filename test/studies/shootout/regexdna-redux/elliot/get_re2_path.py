#!/usr/bin/env python

import os
import sys

util_dir = os.path.join(os.getenv('CHPL_HOME'), 'util', 'chplenv')
sys.path.insert(0, os.path.abspath(util_dir))

from chplenv import chpl_home_utils
from chplenv import chpl_regexp

def get():
    third_party = chpl_home_utils.get_chpl_third_party()
    uniq_cfg_path = chpl_regexp.get_uniq_cfg_path()
    re2_install_dir = os.path.join(third_party, 're2', 'install',
                                   uniq_cfg_path)
    return re2_install_dir


def _main():
    re2_install_dir = get();
    sys.stdout.write("{0}\n".format(re2_install_dir))


if __name__ == '__main__':
    _main()
