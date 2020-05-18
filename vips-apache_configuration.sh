# Install the Apache web server as frontend
# variable declaration again
INITIAL_DIRECTORY=$(pwd)
CODE_USER=wildfly

WILDFLY_VERSION=16.0.0.Final
WILDFLY_HOME=/home/$CODE_USER/wildfly-$WILDFLY_VERSION
WILDFLY_CONFIG_PATH=$WILDFLY_HOME/standalone/configuration

cd $INITIAL_DIRECTORY

read -p "Server name of this VIPSLogic installation (e.g. logic.vips.foo.org): " servername
apt-get --assume-yes install apache2
a2enmod proxy_http headers ssl

cp $INITIAL_DIRECTORY/apache_config/vipslogic.conf /etc/apache2/sites-available/

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
printf "\n----------------------------------------------------------------------------\n"
printf "   Populating the VIPSLogic database with your organization's information "
printf "\n----------------------------------------------------------------------------\n"

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
country_code=${country_code^^} # bhabesh 10-may-2020 : convert upper case to avoid foreign key constraint
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
while [ "$naerstadmodel_deploy_token" == "" ]
do
        read -p "GitLab deploy token for the Naerstad late blight model [*]: " naerstadmodel_deploy_token
done
while [ "$naerstadmodel_deploy_password" == "" ]
do
        read -p "GitLab deploy password for the Naerstad late blight model [*]: " naerstadmodel_deploy_password
done

# Clone VIPSCore, VIPSCoreManager and the Nærstad model from GitLab
sudo -H -u $CODE_USER bash -c "git clone --single-branch --branch master https://$vipscore_deploy_token:$vipscore_deploy_password@gitlab.nibio.no/VIPS/VIPSCore.git ~/VIPSCore"
sudo -H -u $CODE_USER bash -c "git clone --single-branch --branch master https://$vipscoremanager_deploy_token:$vipscoremanager_deploy_password@gitlab.nibio.no/VIPS/VIPSCoreManager.git ~/VIPSCoreManager"
sudo -H -u $CODE_USER bash -c "git clone --single-branch --branch master https://$naerstadmodel_deploy_token:$naerstadmodel_deploy_password@gitlab.nibio.no/VIPS/Model_NAERSTADMO.git ~/Model_NAERSTADMO"

# Build the components
cd /home/$CODE_USER/VIPSCore
sudo -H -u $CODE_USER bash -c "mvn install -DskipTests"
cd ../VIPSCoreManager
sudo -H -u $CODE_USER bash -c "mvn install -DskipTests"
cd ../Model_NAERSTADMO
sudo -H -u $CODE_USER bash -c "mvn install -DskipTests"

# Link the components to the WildFly deployments folder
sudo -H -u $CODE_USER bash -c "ln -s /home/$CODE_USER/VIPSCore/target/VIPSCore-1.0-SNAPSHOT.war $WILDFLY_HOME/standalone/deployments/"
sudo -H -u $CODE_USER bash -c "ln -s /home/$CODE_USER/VIPSCoreManager/target/VIPSCoreManager-1.0-SNAPSHOT.war $WILDFLY_HOME/standalone/deployments/"

# Copy the Naerstad model to the modelcontainer module
sudo -H -u $CODE_USER bash -c "cp /home/$CODE_USER/Model_NAERSTADMO/target/NaerstadModel-1.0-SNAPSHOT.jar $WILDFLY_HOME/modules/no/nibio/vips/modelcontainer/main/"

# Initializing the database for vipscoremanager
printf "\nDATABASE USER INFORMATION for vipscoremanager\n"
printf "We will create a postgresql user 'vipscoremanager' which will own the 'vipscoremanager' database\n"
while [ "$vipscoremanager_password" == "" ]
do
        read -sp "Password for vipscoremanager [*]: " vipscoremanager_password
done

cd $INITIAL_DIRECTORY
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
while [ "$corebatch_password" == "" ]
do
        read -sp "Core batch password (Allowing VIPSLogic to run models in VIPSCore) " corebatch_password
done


cd $INITIAL_DIRECTORY/wildfly_config
sudo -H -u $CODE_USER bash -c "python3 init_standalone_xml_for_vipscoremanager_and_vipscore.py --md5salt $md5salt_2 --dbpassword $vipscoremanager_password --corebatch_username VIPSLogic --corebatch_password $corebatch_password --path $WILDFLY_CONFIG_PATH"

# Testing Wildfly/VIPSCore/VIPSCoreManager
# Run and test WildFly with VIPSLogic deployed
# If successful, this will migrate the vipslogic database to its correct state
echo "TESTING deployment of VIPSCore and VIPSCoreManager on WildFly. Please wait"
# Start WildFly
sudo -H -u $CODE_USER bash -c "$WILDFLY_HOME/bin/standalone.sh > /dev/null &"
#sudo -H -u $CODE_USER bash -c "$WILDFLY_HOME/bin/standalone.sh &"
# Periodically test a database dependant endpoint
sleep 10s
response=400
counter=0
while [ $response -ne 200 ]
do
        sleep 3s
        response=$(curl --write-out %{http_code} --connect-timeout 3 --silent --output /dev/null localhost:8080/VIPSCoreManager/models)
        counter=$(($counter+1))
        if [ $counter -gt 10 ]
        then
                echo "Could not start VIPSCore/VIPSCoreManager on WildFly. Exiting"
                sudo pkill --newest java
                exit 1
        fi
        echo "HTTP response from server: $response"
done

echo "VIPSCore and VIPSCoreManager successfully deployed to WildFly. Shutting down Wildfly"
sudo pkill --newest java
sleep 5s

# Adding organization info (after first Flyway init of VIPSCoreManager)
cd $INITIAL_DIRECTORY
passwordhash_2=$(./md5pass.py $corebatch_password $md5salt_2)
PGPASSWORD=$vipscoremanager_password psql -U vipscoremanager -d vipscoremanager  -h localhost -c "BEGIN;TRUNCATE public.organization CASCADE;INSERT INTO public.organization(organization_id,organization_name,parent_organization_id) VALUES(1,'$organization_name',NULL); INSERT INTO vips_core_user (vips_core_user_id, first_name, last_name, organization_id) VALUES (-10, '', 'VIPSLogic', 1); INSERT INTO vips_core_credentials (id, username, password, vips_core_user_id) VALUES (1, 'vipsbatch', '$passwordhash_2', -10);COMMIT;"




echo "-----------------------------------"
echo "    INSTALLATION COMPLETE"
echo "-----------------------------------"
echo "Now run sudo systemctl start wildfly.service to start the system. Then open up a web browser and go to http://$servername"

