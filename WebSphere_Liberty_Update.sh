#!/bin/bash
# Updating WebSPhere Liberty version + additional features
# FILL your source dir FP_DIR_SOURCE, FEATURE_DIR_SOURCE and check the server names/profiles.
# The current script is for a specific application profile setup 
FP_DIR_SOURCE="LibertyFP23.0.0.12"
FEATURE_DIR_SOURCE="/var/apphome/WAS-Updates/LibertyFP23.0.0.12/wlp-featureRepo-23.0.0.12.zip"
FP_DIR="/var/apphome/WAS-Updates/$FP_DIR_SOURCE"
WAS_PROCESSES=`pgrep -f Liberty`
WAS_PROFILE=`ps -ef | grep exam$(echo $HOSTNAME | sed 's/[^0-9]*//g') | grep -v grep | awk '{ print substr($0, length($0)-12) }'`
HOST=$(echo $HOSTNAME | sed 's/[^0-9]*//g')
#Stop all WAS proccesses
if [ "($WAS_PROCESSES)" != "" ]
                then
                        for i in $WAS_PROCESSES
                        do
                                kill -9 $i
                        done
                echo "WebSphere liberty has been stopped"
else
                echo "no running WebSphere Liberty processes"
fi

#UPDATE ALL WAS COMPONENTS

echo Updating WAS Liberty:
for i in `find /opt/ -name imcl`
do
    $i updateAll -repositories `find $FP_DIR -name repository.config | grep -v IM | tr '\n' ', '` -acceptLicense -sP
done

#UPDATE LIBERTY FEATURES
echo Updating Liberty Features
/opt/IBM/WebSphere/Liberty/bin/installUtility install --from=$FEATURE_DIR_SOURCE --acceptLicense 128_TEST$HOST-1 128_TEST$HOST-2

#Check Version
echo Installed Packages:
/opt/IBM/InstallationManager/eclipse/tools/imcl listInstalledPackages -long

#Start all WAS proccesses
echo Starting Servers:
#/opt/IBM/WebSphere/Liberty/bin/server start 128_TEST$HOST-1
#/opt/IBM/WebSphere/Liberty/bin/server start 128_TEST$HOST-2
systemctl start websphereLiberty_128_TEST$HOST-1
systemctl start websphereLiberty_128_TEST$HOST-2

#Check if The processes are started

if [ "($WAS_PROCESSES)" != "" ]
                then
                     echo The following processes are running $WAS_PROFILE
else
                echo "no running WebSphere Liberty processes, please do a manual check!"
