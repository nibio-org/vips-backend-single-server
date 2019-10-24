#!/bin/bash
# INSTALLS VIPSLogic, VIPSCoreManager and VIPSCore on a vanilla Ubuntu 18 server
# (c) 2019 NIBIO
# Author Tor-Einar Skog <tor-einar.skog@nibio.no>

CODE_USER=wildfly
INITIAL_DIRECTORY=$(pwd)

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
while [ "$vipscore_deploy_token" == "" ]
do
        read -p "GitLab deploy token for VIPSCore [*]: " vipscore_deploy_token
done
while [ "$vipscore_deploy_password" == "" ]
do
        read -p "GitLab deploy password for VIPSCore [*]: " vipscore_deploy_password
done
while [ "$vipscoremanager_deploy_token" == "" ]
do
        read -p "GitLab deploy token for VIPSCoreManager [*]: " vipscoremanager_deploy_token
done
while [ "$vipscoremanager_deploy_password" == "" ]
do
        read -p "GitLab deploy password for VIPSCoreManager [*]: " vipscoremanager_deploy_password
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


# Download and unzip Wildfly 16
cd ..
WILDFLY_VERSION=16.0.0.Final
sudo -H -u $CODE_USER bash -c "wget https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz"
sudo -H -u $CODE_USER bash -c "tar xzf wildfly-$WILDFLY_VERSION.tar.gz"
sudo -H -u $CODE_USER bash -c "rm wildfly-$WILDFLY_VERSION.tar.gz"

# Edit standalone.xml, the Wildfly config file
printf "\nWILDFLY CONFIGURATION\n"
while [ "$smtpserver" == "" ]
do
	read -p "SMTP servername [*]: " smtpserver
done
while [ "$md5salt" == "" ]
do
	read -p "MD5 salt (to make the one-way encryption much harder to break. Type 10-20 random characters) [*]: " md5salt
done

WILDFLY_HOME=/home/$CODE_USER/wildfly-$WILDFLY_VERSION
WILDFLY_CONFIG_PATH=$WILDFLY_HOME/standalone/configuration

cd $INITIAL_DIRECTORY/wildfly_config
sudo -H -u $CODE_USER bash -c "python3 init_standalone_xml.py --smtpserver $smtpserver --md5salt $md5salt --dbpassword $vipslogic_password --path $WILDFLY_CONFIG_PATH"

# Add the required modules for VIPSLogic to Wildfly
# PostgreSQL
# etc
# All modules needed to run VIPSLogic AND VIPSCore are added
sudo -H -u $CODE_USER bash -c "cp -r modules/* $WILDFLY_HOME/modules"

# Set up WildFly as a systemd service
mkdir /etc/wildfly
cp systemd_templates/wildfly.conf /etc/wildfly
cp systemd_templates/wildfly.service /etc/systemd/system
sed -i -e "s,WILDFLY_PATH_REPLACE_WITH_SED,$WILDFLY_HOME," /etc/systemd/system/wildfly.service
sudo -H -u $CODE_USER bash -c "cp systemd_templates/launch.sh $WILDFLY_HOME/bin"
sed -i -e "s,WILDFLY_PATH_REPLACE_WITH_SED,$WILDFLY_HOME," $WILDFLY_HOME/bin/launch.sh
chmod +x $WILDFLY_HOME/bin/launch.sh 

# Add VIPSLogic to the Wildfly deployments folder
sudo -H -u $CODE_USER bash -c "ln -s /home/$CODE_USER/VIPSLogic/target/VIPSLogic-1.0-SNAPSHOT.war $WILDFLY_HOME/standalone/deployments/"


# Run and test WildFly with VIPSLogic deployed
# If successful, this will migrate the vipslogic database to its correct state
echo "TESTING THE WILDFLY APPLICATION SERVER. Please wait"
# Start WildFly
sudo -H -u $CODE_USER bash -c "$WILDFLY_HOME/bin/standalone.sh > /dev/null &"
# Periodically test a database dependant endpoint
sleep 10s
response=400
counter=0
while [ $response -ne 200 ]
do
        sleep 3s
        response=$(curl --write-out %{http_code} --connect-timeout 3 --silent --output /dev/null localhost:8080/VIPSLogic/rest/organization)
        counter=$(($counter+1))
        if [ $counter -gt 10 ]
        then
                echo "Could not start WildFly. Exiting"
                sudo pkill --newest java
                exit 1
        fi
        echo "HTTP response from server: $response"
done

echo "WildFly started successfully. Installing Apache as frontend."

# Install the Apache web server as frontend
cd $INITIAL_DIRECTORY
read -p "Server name of this VIPSLogic installation (e.g. logic.vips.foo.org): " servername
apt-get --assume-yes install apache2
a2enmod proxy_http headers ssl
cp apache_config/vipslogic.conf /etc/apache2/sites-available/
sed -i -e "s,SERVER_NAME_REPLACE_WITH_SED,$servername," /etc/apache2/sites-available/vipslogic.conf
sudo -H -u $CODE_USER bash -c "mkdir /home/$CODE_USER/static"
sed -i -e "s,CODE_USER_REPLACE_WITH_SED,$CODE_USER," /etc/apache2/sites-available/vipslogic.conf
a2ensite vipslogic
systemctl restart apache2

# Test it
echo "127.0.0.1 $servername" >> /etc/hosts

response=$(curl --write-out %{http_code} --connect-timeout 3 --silent --output /dev/null http://$servername/rest/organization)
if [ $response -ne 200 ]
then
	echo "Error configuring Apache. Server returned status code $response. Exiting"
	exit 1
fi

echo "Apache and WildFly correctly set up. Shutting down Wildfly"
sudo pkill --newest java
sleep 5s


# Next up is adding organization information
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

printf "\nINITIAL ADMIN USER INFO\n"
while [ "$user_email" == "" ]
do
        read -p "Email [*]: " user_email
done
read -p "First name: " first_name
while [ "$last_name" == "" ]
do
        read -p "Last name [*]: " last_name
done
read -p "Username: " username

read -sp "Password for $username [*]: " user_password

passwordhash=$(./md5pass.py $user_password $md5salt)

PGPASSWORD=$vipslogic_password psql -U vipslogic -d vipslogic  -h localhost -c "BEGIN;TRUNCATE public.organization CASCADE; INSERT INTO public.organization(organization_name,address1,address2,postal_code,country_code,default_locale,default_map_center,default_map_zoom,default_time_zone,city) VALUES('$organization_name','$address_1','$address_2','$postal_code','$country_code','$default_language',ST_GeomFromText('POINT($longitude $latitude)',4326),4,'$timezone','$city');COMMIT;"

PGPASSWORD=$vipslogic_password psql -U vipslogic -d vipslogic  -h localhost -c "BEGIN;INSERT INTO public.vips_logic_user(email,first_name,last_name,organization_id,user_status_id,preferred_locale) VALUES('$user_email','$first_name','$last_name',(SELECT organization_id FROM public.organization WHERE organization_name='$organization_name'),4,'$default_language'); COMMIT;"

PGPASSWORD=$vipslogic_password psql -U vipslogic -d vipslogic  -h localhost -c "BEGIN;INSERT INTO public.user_authentication(user_id,user_authentication_type_id,username,password) VALUES((SELECT user_id FROM public.vips_logic_user WHERE first_name='$first_name' AND last_name='$last_name'),1,'$username','$passwordhash'); COMMIT;"

PGPASSWORD=$vipslogic_password psql -U vipslogic -d vipslogic  -h localhost -c "BEGIN;INSERT INTO public.user_vips_logic_role(vips_logic_role_id,user_id) VALUES(1,(SELECT user_id FROM public.vips_logic_user WHERE last_name='$last_name')); COMMIT;"

echo "---------------------------------------------------"
echo "    VIPSLogic installed successfully               "
echo "    Next: Install VIPSCore and VIPSCoreManager     "
echo "---------------------------------------------------"

# Clone VIPSCore and VIPSCoreManager from GitLab
sudo -H -u $CODE_USER bash -c "git clone --single-branch --branch master https://$vipscore_deploy_token:$vipscore_deploy_password@gitlab.nibio.no/VIPS/VIPSCore.git ~/VIPSCore"
sudo -H -u $CODE_USER bash -c "git clone --single-branch --branch master https://$vipscoremanager_deploy_token:$vipscoremanager_deploy_password@gitlab.nibio.no/VIPS/VIPSCoreManager.git ~/VIPSCoreManager"

# Build the components
cd ../VIPSCore
sudo -H -u $CODE_USER bash -c "mvn install -DskipTests"
cd ../VIPSCoreManager
sudo -H -u $CODE_USER bash -c "mvn install -DskipTests"

# Link the components to the WildFly deployments folder
sudo -H -u $CODE_USER bash -c "ln -s /home/$CODE_USER/VIPSCore/target/VIPSCore-1.0-SNAPSHOT.war $WILDFLY_HOME/standalone/deployments/"
sudo -H -u $CODE_USER bash -c "ln -s /home/$CODE_USER/VIPSCore/target/VIPSCoreManager-1.0-SNAPSHOT.war $WILDFLY_HOME/standalone/deployments/"

# Initializing the database for vipscoremanager
printf "\nDATABASE USER INFORMATION for vipscoremanager\n"
printf "We will create a postgresql user 'vipscoremanager' which will own the 'vipscoremanager' database\n"
while [ "$vipscoremanager_password" == "" ]
do
        read -sp "Password for vipscoremanager [*]: " vipscoremanager_password
done

sudo -H -u postgres bash -c "psql -v vipscoremanager_password=\"'$vipscoremanager_password'\" -f db/vipscoremanager_init_1.sql"

# Edit standalone.xml, the Wildfly config file, for VIPSCoreManager
printf "\nWILDFLY CONFIGURATION for VIPSCoreManager\n"
while [ "$smtpserver" == "" ]
do
        read -p "SMTP servername [*]: " smtpserver
done
while [ "$md5salt_2" == "" ]
do
        read -p "MD5 salt (to make the one-way encryption much harder to break. Type 10-20 random characters) [*]: " md5salt_2
done
while [ "$corebatch_username" == "" ]
do
	read -p "Core batch username (Allowing VIPSLogic to run models in VIPSCore) " corebatch_username
done
while [ "$corebatch_password" == "" ]
do
        read -p "Core batch password (Allowing VIPSLogic to run models in VIPSCore) " corebatch_password
done


cd $INITIAL_DIRECTORY/wildfly_config
sudo -H -u $CODE_USER bash -c "python3 init_standalone_xml_for_vipscoremanager_and_vipscore.py --md5salt $md5salt_2 --dbpassword $vipscoremanager_password --corebatch_username $corebatch_username --corebatch_password $corebatch_password --path $WILDFLY_CONFIG_PATH"


echo "-----------------------------------"
echo "    INSTALLATION COMPLETE"
echo "-----------------------------------"
echo "Now run sudo systemctl start wildfly.service to start the system"
