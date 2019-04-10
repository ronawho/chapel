#!/usr/bin/env python
import os
import sys
import tempfile

chplenv_dir = os.path.join(os.path.dirname(__file__), '..', 'chplenv')
sys.path.insert(0, os.path.abspath(chplenv_dir))

import chpl_home_utils
import chpl_hwloc
import chpl_3p_hwloc_configs
import utils


def get_lstopo():
    hwloc = chpl_hwloc.get()
    cmd = 'lstopo-no-graphics'
    if hwloc == 'none':
        lstopo = None
    elif hwloc == 'system':
        lstopo = cmd
    elif hwloc == 'hwloc':
        third_party = chpl_home_utils.get_chpl_third_party()
        uniq_cfg_path = chpl_3p_hwloc_configs.get_uniq_cfg_path()
        lstopo = os.path.join(third_party, 'hwloc', 'install',
                              uniq_cfg_path, 'bin', cmd )
    return lstopo

def get_xml_file():
    return os.path.join(tempfile.gettempdir(), 'lstopo.xml')


def _main():
    lstopo = get_lstopo()
    xml_file = get_xml_file()
    cmd = [lstopo, '--force', '--no-io', '--no-icaches', xml_file]
    utils.run_command(cmd)
    sys.stdout.write("{0}".format(xml_file))


if __name__ == '__main__':
    _main()
