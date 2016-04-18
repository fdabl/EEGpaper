#!/usr/bin/env python
import os
import sys
from os.path import basename, normpath


def prepare(ffile):
    name, ext = ffile.split('.')
    tex, bib, pdf = ['.'.join([name, ext]) for ext in ['tex', 'bcf', 'pdf']]

    os.system('pweave -f tex {0}'.format(ffile))
    os.system('pdflatex {0}'.format(tex))
    os.system('biber {0}'.format(bib))
    os.system('pdflatex {0}'.format(tex))
    os.system('evince {0} &'.format(pdf))



if __name__ == '__main__':
    ffile = basename(normpath(sys.argv[1]))
    prepare(ffile)
