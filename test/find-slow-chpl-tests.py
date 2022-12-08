import re
import argparse

"""
Report chpl test times
"""

def create_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('logfile', type=argparse.FileType('r'),
                        help='logfile to search')
    parser.add_argument('--time', type=float, default=25,
                        help='time threshold to display')
    parser.add_argument('--mode', default='compilation',
                        choices=['compilation', 'execution', 'subtest'],
                        help='what type of time to search for')
    return parser


args = create_parser().parse_args()
if args.mode =='subtest':
    reg = re.compile('\[Finished subtest "(.*)" - (.*) seconds')
else:
    reg = re.compile('\[Elapsed {} time for "(.*)" - (.*) seconds'.format(args.mode))
lines = [line.strip() for line in args.logfile if reg.match(line)]
res = [(float(m.group(2)), m.group(1)) for l in lines for m in [reg.match(l)] if m]
res.sort(reverse=True)

for r in res:
    if r[0] > args.time:
        print(r)
