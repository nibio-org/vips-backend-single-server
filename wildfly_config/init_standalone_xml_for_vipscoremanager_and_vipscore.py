#!/usr/bin/python3

# Adds VIPSCore and VIPSCoreManager specific config to [WILDFLY_HOME]/standalone/configuration/standalone.xml
# (c) 2019 NIBIO
# Author Tor-Einar Skog <tor-einar.skog@nibio.no>

from shutil import copyfile
from xml.dom.minidom import parse
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--md5salt")
parser.add_argument("--dbpassword")
parser.add_argument("--corebatch_username")
parser.add_argument("--corebatch_password")
parser.add_argument("--path")
args = parser.parse_args()

path = args.path
# Make a copy of the original file
copyfile(path + "/standalone.xml", path + "/standalone_original.xml")

# The destination document
standalone_dom = parse(path + "/standalone.xml")

# The system properties to add to destination (standalone.xml)
vsp_dom = parse("vipscoremanager_system_properties.xml")

system_properties = standalone_dom.getElementsByTagName("system-properties")
if len(system_properties) == 0:
    system_properties = standalone_dom.createElement("system-properties")
    standalone_dom.getElementsByTagName("server")[0].insertBefore(system_properties, standalone_dom.getElementsByTagName("management")[0])
else:
    system_properties = system_properties[0]

# Transfer system properties to standalone.xml
for property in vsp_dom.getElementsByTagName("property"):
    # We use script input parameters to set system property values
    if property.getAttribute("name") == "no.nibio.vips.coremanager.MD5_SALT":
        property.setAttribute("value",args.md5salt)
    if property.getAttribute("name") == "no.nibio.vips.logic.CORE_BATCH_USERNAME":
        property.setAttribute("value",args.corebatch_username)
    if property.getAttribute("name") == "no.nibio.vips.logic.CORE_BATCH_PASSWORD":
        property.setAttribute("value",args.corebatch_password)
    system_properties.appendChild(property)


# Transfer the data source and driver info to standalone.xml
vipscoremanager_datasource_dom = parse("vipscoremanager_datasource.xml")
datasources_elm = vipscoremanager_datasource_dom.getElementsByTagName("datasources")[0]
standalone_datasources_elm = standalone_dom.getElementsByTagName("datasources")[0]
vipscoremanager_datasource = None
for datasource in datasources_elm.getElementsByTagName("datasource"):
    if datasource.getAttribute("jndi-name") == "java:jboss/datasources/vipscoremanager":
        datasource.getElementsByTagName("security")[0].getElementsByTagName("password")[0].firstChild.replaceWholeText(args.dbpassword)
        standalone_datasources_elm.appendChild(datasource)
# Assuming PostgreSQL driver has been added by init_standalone.py for VIPSLogic

# Write to file
outputfile = open(path + "/standalone.xml", "w")
outputfile.write(standalone_dom.toxml())
outputfile.close()
