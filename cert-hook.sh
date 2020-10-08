#!/bin/bash
#LEGO_ACCOUNT_EMAIL
#LEGO_CERT_DOMAIN
#LEGO_CERT_PATH
#LEGO_CERT_KEY_PATH

cert_path=/volumes/nginx-persistence/certificates
printf "\nCopying certificates for ${LEGO_CERT_DOMAIN} into ${cert_path}\n"
sudo cp $LEGO_CERT_PATH $cert_path/server.crt
sudo cp $LEGO_CERT_KEY_PATH $cert_path/server.key
printf "Done copying certs\n"