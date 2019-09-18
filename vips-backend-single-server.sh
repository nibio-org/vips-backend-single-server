#!/bin/bash
# INSTALLS VIPSLogic, VIPSCoreManager and VIPSCore on a vanilla Ubuntu 18 server
# (c) 2019 NIBIO
# Author Tor-Einar Skog <tor-einar.skog@nibio.no>

CODE_USER=wildfly

# Locale update
# We want the server to user UTF-8 as standard
locale-gen en_US.UTF-8
# dpkg-reconfigure locales # probably double work, remove if not needed

# Database install and setup
# If you have a separate data disk for the database,
# then you need to perform some manual steps after installing 
# postgresql. They are not described here.
apt-get --assume-yes install postgresql postgis

# Initialize the VIPSLogic database
printf "\n\nInitializing the VIPSLogic database\n"
printf "We need some input from you before doing that\n"
printf "Required fields are marked with [*]"

printf "\nDATABASE USER INFORMATION\n"
printf "We will create a postgresql user 'vipslogic' which will own the 'vipslogic' database\n"
while [ "$vipslogic_password" == "" ]
do
	read -sp "Password for vipslogic [*]: " vipslogic_password
done

sudo -H -u postgres bash -c "psql -v vipslogic_password=\"'$vipslogic_password'\" -f db/vipslogic_init_1.sql"

printf "Done with database initialization part 1 (of 3)"

printf "\n\nBUILD THE APPLICATION\n"
printf "\nInstalling OpenJDK11 and build tool Maven\n"
apt-get install --assume-yes openjdk-11-jdk maven

# Download, compile and deploy VIPSLogic
# We need a deploy key for that
printf "\n\nDOWNLOADING VIPSLOGIC SOURCE CODE"
printf "\nYou need access to the VIPSLogic and VIPSCommon GitLab repositories before you can proceed\n"
while [ "$vipslogic_deploy_token" == "" ]
do
	read -p "GitLab deploy token for VIPSLogic [*]: " vipslogic_deploy_token
done
while [ "$vipslogic_deploy_password" == "" ]
do
	read -p "GitLab deploy password for VIPSLogic [*]: " vipslogic_deploy_password
done
while [ "$vipscommon_deploy_token" == "" ]
do
	read -p "GitLab deploy token for VIPSCommon [*]: " vipscommon_deploy_token
done
while [ "$vipscommon_deploy_password" == "" ]
do
	read -p "GitLab deploy password for VIPSCommon [*]: " vipscommon_deploy_password
done

printf "\nWe also need to create a user for compiling and running the code\n"

# Add local user for code deployment and running of the Wildfly Application server
adduser $CODE_USER

# Clone VIPSCommon and VIPSLogic from GitLab
sudo -H -u $CODE_USER bash -c "git clone --single-branch --branch master https://$vipslogic_deploy_token:$vipslogic_deploy_password@gitlab.nibio.no/VIPS/VIPSLogic.git ~/VIPSLogic"
sudo -H -u $CODE_USER bash -c "git clone --single-branch --branch master https://$vipscommon_deploy_token:$vipscommon_deploy_password@gitlab.nibio.no/VIPS/VIPSCommon.git ~/VIPSCommon"

# Build the source code
cd /home/$CODE_USER/VIPSCommon
sudo -H -u $CODE_USER bash -c "mvn install -DskipTests"
cd ../VIPSLogic
sudo -H -u $CODE_USER bash -c "mvn install -DskipTests"

# Download Wildfly 16
sudo -H -u $CODE_USER bash -c "https://download.jboss.org/wildfly/16.0.0.Final/wildfly-16.0.0.Final.tar.gz"
sudo -H -u $CODE_USER bash -c "tar xzf wildfly-16.0.0.Final.tar.gz"


printf "\nORGANIZATION INFO\n"
while [ "$organization_name" == "" ]
do
        read -p "Organization name [*] (e.g. NIBIO): " organization_name
done
read -p "Address 1: " address_1
read -p "Address 2: " address_2
read -p "ZIP/Postal code: " postal_code
read -p "City: " city
while [ "$country_code" == "" ]
do
        read -p "Country code [*] (Two letters, see https://www.worldatlas.com/aatlas/ctycodes.htm): " country_code
done
read -p "Default language and locale [*] (See https://docs.oracle.com/javase/8/docs/api/java/util/Locale.html): " default_language
read -p "Web map default center longitude (WGS84):" longitude
read -p "Web map default center latitude (WGS84):" latitude
read -p "Default timezone (See https://docs.oracle.com/javase/8/docs/api/java/util/TimeZone.html): " timezone

printf "\nINITIAL ADMIN USER INFO"
while [ "$user_email" == "" ]
do
        read -p "Email [*]: " user_email
done
read -p "First name: " first_name
while [ "$last_name" == "" ]
do
        read -p "Last name [*]: " last_name
done

