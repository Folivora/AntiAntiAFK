#!/usr/bin/env python3

## Provide access to get_variable() function of get_variable.py from bash.
##

import sys

sys.path.insert(1, './functions')
from get_variable import get_variable 

del sys.argv[0]
print(get_variable(*sys.argv))
