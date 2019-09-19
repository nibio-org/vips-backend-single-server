#!/usr/bin/python3

# Adds VIPSLogic specific config to [WILDFLY_HOME]/standalone/configuration/standalone.xml
# (c) 2019 NIBIO
# Author Tor-Einar Skog <tor-einar.skog@nibio.no>

from shutil import copyfile
from xml.dom.minidom import parse
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--smtpserver")
parser.add_argument("--md5salt")
parser.add_argument("--dbpassword")
parser.add_argument("--path")
args = parser.parse_args()

path = args.path
# Make a copy of the original file
copyfile(path + "standalone.xml", path + "standalone_original.xml")

# The destination document
standalone_dom = parse(path + "standalone.xml")

# The system properties to add to destination (standalone.xml)
vsp_dom = parse("vipslogic_system_properties.xml")

system_properties = standalone_dom.getElementsByTagName("system-properties")
if len(system_properties) == 0:
    system_properties = standalone_dom.createElement("system-properties")
    standalone_dom.getElementsByTagName("server")[0].insertBefore(system_properties, standalone_dom.getElementsByTagName("management")[0])

# Transfer system properties to standalone.xml
for property in vsp_dom.getElementsByTagName("property"):
    # We use script input parameters to set system property values
    if property.getAttribute("name") == "no.nibio.vips.logic.MD5_SALT":
        property.setAttribute("value",args.md5salt)
    if property.getAttribute("name") == "no.nibio.vips.logic.SMTP_SERVER":
        property.setAttribute("value",args.smtpserver)
    system_properties.appendChild(property)

# Transfer the data source and driver info to standalone.xml
vipslogic_datasource_dom = parse("vipslogic_datasource_and_driver.xml")
datasources_elm = vipslogic_datasource_dom.getElementsByTagName("datasources")[0]
standalone_datasources_elm = standalone_dom.getElementsByTagName("datasources")[0]
vipslogic_datasource = None
for datasource in datasources_elm.getElementsByTagName("datasource"):
    if datasource.getAttribute("jndi-name") == "java:jboss/datasources/vipslogic":
        datasource.getElementsByTagName("security")[0].getElementsByTagName("password")[0].firstChild.replaceWholeText(args.dbpassword)
        standalone_datasources_elm.appendChild(datasource)
drivers_elm = vipslogic_datasource_dom.getElementsByTagName("drivers")[0]
standalone_drivers_elm = standalone_dom.getElementsByTagName("drivers")[0]
for driver in drivers_elm.getElementsByTagName("driver"):
    if driver.getAttribute("name") == "postgresql":
        standalone_drivers_elm.appendChild(driver)


# Write to file
outputfile = open(path + "standalone.xml", "w")
outputfile.write(standalone_dom.toxml())
outputfile.close()
