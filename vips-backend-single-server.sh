#!/bin/bash
# INSTALLS VIPSLogic, VIPSCoreManager and VIPSCore on a vanilla Ubuntu 18 server
# (c) 2019 NIBIO
# Author Tor-Einar Skog <tor-einar.skog@nibio.no>

# Locale update
# We want the server to user UTF-8 as standard
locale-gen en_US.UTF-8
#sudo dpkg-reconfigure locales

# Database install and setup
# If you have a separate data disk for the database,
# then you need to perform some manual steps after installing 
# postgresql. They are not described here.
sudo apt-get install postgresql postgis

# Initialize the VIPSLogic database
printf "\n\nInitializing the VIPSLogic database"
printf "We need some input from you before doing that"
printf "Required fields are marked with [*]"

printf "\nDATABASE USER INFORMATION"
printf "We will create a postgresql user 'vipslogic' which will own the 'vipslogic' database"
while [ "$vipslogic_password" == "" ]
do
	read -sp "Password for vipslogic [*]: " vipslogic_password
done

sudo -H -u postgres bash -c "psql -v vipslogic_password=\"'$vipslogic_password'\" -f db/vipslogic_init_1.sql"

printf "Done with database initialization part 1 (of 3)"

# Download, compile and deploy VIPSLogic
# We need a deploy key for that
printf "\n\nDOWNLOADING VIPSLOGIC SOURCE CODE"
printf "\nYou need access to the VIPSLogic GitLab repository before you can proceed\n"
read -p "GitLab deploy token [*]: " deploy_token
read -p "GitLab deploy password [*]: " deploy_password
git clone https://$deploy_token:$deploy_password@gitlab.nibio.no/VIPS/VIPSLogic.git

printf "\nVIPSLogic source code downloaded. Installing OpenJDK11 and build tool Maven\n"
apt-get install openjdk-11-jdk maven



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

