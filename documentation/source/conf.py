# Configuration file for the Sphinx documentation builder.

import os
import sys
sys.path.insert(0, os.path.abspath('../../_packages/sphinx-extensions/current/src/sphinxcontrib'))

project = 'command-line-parser'
copyright = '2022, Dylan Hackers'
author = 'Dylan Hackers'
release = 'v3.2.0'
exclude_patterns = ['_build']
primary_domain = 'dylan'
html_theme = 'furo'             # sudo pip install furo
html_title = 'command-line-parser'
extensions = [
    'dylan.domain',
    'sphinx.ext.intersphinx'
]

# Ignore certification verification
tls_verify = False
