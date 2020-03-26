# VIPS Backend single server

This repository contains scripts and documentation for configuring the VIPS backend systems (VIPSLogic, VIPSCoreManager and VIPSCore) on a single Linux server.

## Requirements
- A clean installation of Ubuntu Linux 18.04 LTS

## Instructions

Before you do this, you need to set the correct locale for the server, by:

`locale-gen en_US.UTF-8`

`sudo dpkg-reconfigure locales`

![Click OK here, nothing to do](/images/dpkg-reconfigure_1.png)
![Select en_US.UTF-8 as the default locale](/images/dpkg-reconfigure_2.png)

You need to clone (download) the entire repository to the server on which you want to install VIPS.

In order to clone this repository, issue this command:

`git clone https://gitlab.nibio.no/vips-setup/vips-backend-single-server.git`

If you get this error message:

`fatal: unable to access 'https://gitlab.nibio.no/vips-setup/vips-backend-single-server.git/': server certificate verification failed. CAfile: /etc/ssl/certs/ca-certificates.crt CRLfile: none`

...then you need to update your SSL certificates, running this command (as ROOT):

`echo $(echo -n | openssl s_client -showcerts -connect gitlab.nibio.no:443 2>/dev/null  | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p') >> /etc/ssl/certs/ca-certificates.crt`

...and then run the git clone command again. 

Make sure that the git repo is globally accessible (not only by ROOT)

cd into the directory vips-backend-single-server/ and run the script:

`sudo ./vips-backend-single-server.sh`

The installation process may take quite a while. You will be asked questions every now and then, so please make sure to check in on the output from time to time.
