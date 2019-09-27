#!/usr/bin/python3

# Sets up Wildfly as a systemd service in Ubuntu
# (c) 2019 NIBIO
# Author: Tor-Einar Skog <tor-einar.skog@nibio.no>

from shutil import copyfile
import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument("--path")
args = parser.parse_args()

path = args.path

# Copy wildfly conf
os.makedirs("/etc/wildfly")
copyfile(wildfly.conf, path + "/
