#!/usr/bin/python3

import sys
import hashlib

password_salted = sys.argv[1] + sys.argv[2]

md5result = hashlib.md5(password_salted.encode())
print(md5result.hexdigest())
