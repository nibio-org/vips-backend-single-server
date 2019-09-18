# VIPS Backend single server

Scripts and documentation for configuring the VIPS backend systems (VIPSLogic, VIPSCoreManager and VIPSCore) on a single Linux server

In order to clone this repository, issue this command:

git clone https://gitlab.nibio.no/vips-setup/vips-backend-single-server.git

If you get this error message:

fatal: unable to access 'https://gitlab.nibio.no/vips-setup/vips-backend-single-server.git/': server certificate verification failed. CAfile: /etc/ssl/certs/ca-certificates.crt CRLfile: none

...then you need to update your SSL certificates, running this command (as ROOT):

echo $(echo -n | openssl s_client -showcerts -connect gitlab.nibio.no:443 2>/dev/null  | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p') >> /etc/ssl/certs/ca-certificates.crt

...and then run the git clone command again

cd into the directory vips-backend-single-server/ and run the script:

sudo ./vips-backend-single-server.sh
