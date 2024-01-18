#!/bin/bash

### Еxporting certificate from provided example.p7b  and adding it to keystore
### Reqirements gsk8capicmd_64,openssl, keytool
### The script is going to ask for certificate label, keystore name and password
### YOU MUST HAVE THE ".KEY" FILE in the same directory.

green='\033[0;32m'
echo -e "${green}AutoCert"

while true; do
read -p "Please enter certificate label"$'\n' cert
        if [ -z "$cert" ]; then
                echo 'Input cannot be blank, please try again.'
                continue
        else
                break
        fi
done

while true; do
        read -p "Please keystore name"$'\n' keystore
        if [ -z "$keystore" ]; then
                echo 'Input cannot be blank, please try again.'
                continue
        elif [ ! -f $keystore ]; then
                echo "$keystore does not exist"
                continue
        else
                break
        fi
done

while true; do
        read -p "Please enter keystore password"$'\n' pass
        if [ -z "$pass" ]; then
                echo 'Input cannot be blank, please try again.'
                continue
        else
                break
        fi
done

        if [ -f $cert.p7b ]; then
                openssl pkcs7 -print_certs -in  $cert.p7b -out  $cert.crt
                if [ -f $cert.crt ]; then
                        echo "$cert.crt has been created!"
                else    
						echo "Openssl was unable to create $cert.crt"
                        exit 0
                fi
        else
                echo "$cert.p7b does not exists, please check the configurations again (certificate name, working directory, permissions) "
                exit 0
        fi
#Creating p12 file
echo "Creating p12 file"
sleep 1
openssl pkcs12 -export -out $cert.p12 -inkey $cert.key -in $cert.crt -name "$cert"
                if [ -f "$cert.p12" ]; then
                        echo "Deleting old label"
            gsk8capicmd_64 -cert -delete -label $cert -db $keystore -pw $pass
                        echo "Importing the certificate to the keystore"
                        sleep 1
                        echo "Importing cert+key from p12 to $keystore"
                        gsk8capicmd_64 -cert -import -db $cert.p12 -label $cert -type pkcs12 -pw "$pass" -target $keystore -target_pw $pass -target_type cms
                else
                        echo "$cert.p12 does not exist, please check file names, permisions, working directory"
                        exit 0
                fi
echo "Check if the correct certificate exists in the keystore $keystore"
sleep 1
gsk8capicmd_64 -cert -details -db plugin-key.kdb -pw "WebAS" -label $cert
