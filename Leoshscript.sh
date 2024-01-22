#!/bin/bash
# The script reads file web66.txt line by line, containing webservers for deletion
# You can use the ansible automation WebServerDeletion.yml to execute the task on multiple hosts
#useConfirm=true - comment out the line below like this to disable confirmation
#useConfirm=true

confirm() {
   [ "$useConfirm" = true ] && read -p "Proceed? (Enter) - (^C to abort)"
}

while IFS= read -r web
do
    echo "$web will be decomissoned"
        if [ -z "$web" ]
        then
                 echo 'Input cannot be blank, please check  again.'
                 exit 0
        fi

        #Function for checking the process for related $web-instance"
        check_Httpd_Stopped()  {
        if [ "$(ps -ef | grep httpd-$web | grep -v grep | awk '{print $2}')" != "" ]
                        then    return 0
                        else    return 1
        fi
        }

        #function for stopping the related web-instance
        stop_httpd() {
        /etc/init.d/httpd-$web stop > /dev/null 2>&1
        }

        #Function removes the web-intance in case RHEL bigger than 6 is used
        stop_httpd_rhel_7() {
        systemctl disable httpd-$web.service
        }

        stop_httpd_rhel_6() {
        chkconfig httpd-$web off
        sleep 5
        }

        #Function which will check up to 3 times if the service related to our set web-instance still running
        kill_httpd()  {
        if [[ $(ps -ef | grep httpd-$web | grep -v grep | awk '{print $2}') ]]; then
                ps -ef | grep httpd-$web | grep -v grep | awk '{print $2}' | xargs kill -9
                echo "$Web has been killed"
        else
                echo "$Web instance is stopped"
        fi

        }
        #Function for decommissioning the script
        decomission_httpd() {
        echo "Delete httpd-$web.service from /etc/systemd/system/"
        rm -f /etc/systemd/system/httpd-$web.service
        sleep 3
        echo "Rename httpd-$web in /etc/init.d/"
        mv /etc/init.d/httpd-$web /etc/init.d/httpd-$web.decommissioned
        sleep 3
        echo "Make script non-executable"
        chmod -x /etc/init.d/httpd-$web.decommissioned
        sleep 3
        }

        #Function which removes all simlink related to the service
        remove_simlink() {
        for i in {0..6}
                do
                unlink /etc/rc.d/rc$i.d/*httpd-$web*
        done
        }

        #Function which delete all related directories to the web instance
        delete_directories() {
        echo "Unlink simlink related to $web in /var/apphome/"
        find /var/apphome/*$web -type l -exec unlink {} \;
        sleep 3
        echo "Delete $web from /var/apphome/"
        confirm
        rm -rf /var/apphome/$web
        sleep 3
        echo "Delete $web from /var/opt/httpd/"
        confirm
        rm -rf /var/opt/httpd/$web
        sleep 3
        echo "Delete $web from /etc/opt/httpd/"
        confirm
        rm -rf /etc/opt/httpd/$web
        sleep 3
        }

        #Function which decommission firewall and related iptables
        deactivate_firewall() {
        if [ -f "/etc/firewall/conf.d/$web-iptables.conf" ]
          then
                echo "The file will be renamed"
                confirm
                mv /etc/firewall/conf.d/$web-iptables.conf  /etc/firewall/conf.d/$web-iptables.conf.decommissioned
        elif [ -f "/etc/firewall/conf.d/done/$web-iptables.conf" ]
           then
                echo "The file will be renamed"
                confirm
                mv /etc/firewall/conf.d/done/$web-iptables.conf /etc/firewall/conf.d/done/$web-iptables.conf.decommissioned
        else
                echo "The file doesn't exist"
        fi
        }

        #Function which deactivates the $eth
        deactivate_adapter() {
        local inetAdd="$(nslookup $web | grep 172 | tr -d ' Address: ')"
        local eth1="$(ifconfig | grep -C1 $inetAdd | grep '^eth' | awk '{print $1}')"
        local eth2="$(ifconfig | grep -C1 $inetAdd | grep '^ens'| awk '{print $1}')"
        echo "Do you want to deactivate adapter $eth1 $eth2 ? "
        confirm
        if [[ ! -z "$eth1" ]]
           then ifconfig $eth1 down
                 echo "Rename adapter $eth1"
                 confirm
                 if [ -f /etc/sysconfig/network-scripts/ifconfig-$eth1 ]
                   then mv /etc/sysconfig/network-scripts/ifconfig-$eth1 /etc/sysconfig/network-scripts/deactivated-ifconfig-$eth1
                 elif [ -f /etc/sysconfig/network-scripts/ifcfg-$eth1 ]
                   then mv /etc/sysconfig/network-scripts/ifcfg-$eth1 /etc/sysconfig/network-scripts/deactivated-ifcfg-$eth1
                 fi
        elif [[ ! -z "$eth2" ]]
           then ifconfig $eth2 down
                 echo "Rename adapter $eth2"
                 confirm
                 if [ -f /etc/sysconfig/network-scripts/ifconfig-$eth2 ]
                   then mv /etc/sysconfig/network-scripts/ifconfig-$eth2 /etc/sysconfig/network-scripts/deactivated-ifconfig-$eth2
                 elif [ -f /etc/sysconfig/network-scripts/ifcfg-$eth2 ]
                   then mv /etc/sysconfig/network-scripts/ifcfg-$eth2 /etc/sysconfig/network-scripts/deactivated-ifcfg-$eth2
                 fi

        fi

        updatedb
        sleep 5
        echo "Check if the adapter is deactivated successfully"
        locate -i $eth1
        locate -i $eth2

        }
        if grep -q -i "release 6" /etc/redhat-release
           then
                echo "Check if there is running process related to httpd-$web"
                  if check_Httpd_Stopped
                        then
                        echo "Web instance $web is running"
                        echo "=========================================="
                        echo "Do you want to stop the web-instance $web?"
                        echo "=========================================="
                        confirm
                        stop_httpd
                        echo "sleep for 5 seconds"
                        sleep 5
                        echo "Check if there is still has running $SERVICE"
                        if ! check_Httpd_Stopped
                        then
                          kill_httpd
                        fi
                  else
                        echo "The web-instance httpd-$web is stopped"
                  fi

                echo "The service related to the httpd-$web will be disabled"
                confirm
                stop_httpd_rhel_6
                echo "The service related to the httpd-$web will be removed"
                confirm
                decomission_httpd
                echo "The simlinks related to the httpd-$web will be unlinked"
                remove_simlink
                echo "The directories related to the httpd-$web will be deleted"
                confirm
                delete_directories
                echo "The firewall will be decommissioned"
                confirm
                deactivate_firewall
                echo "Free the associated Ethernet adapter"
                confirm
                deactivate_adapter
                sleep 2
                echo "$web has been removed"
                echo ""
                echo "Running additional check.."
                updatedb
                sleep 5
                locate -i $web

        else
          echo "bigger than rhel 6"
          echo "Check if there is running process related to httpd-$web"
                  if check_Httpd_Stopped
                        then
                        echo "Web instance $web is running"
                        echo "=========================================="
                        echo "Stopping web instance $web"
                        echo "=========================================="
                        confirm
                        stop_httpd
                        echo "sleep for 3 seconds"
                        sleep 3
                        echo "Check if there is still has running $SERVICE"
                        if ! check_Httpd_Stopped
                        then
                          kill_httpd
                        fi
                  else
                        echo "The web-instance httpd-$web is stopped"
                  fi

                echo "The service related to the httpd-$web will be disabled"
                confirm
                stop_httpd_rhel_7
                echo "he service related to the httpd-$web will be removed"
                confirm
                decomission_httpd
                echo "The simlinks related to the httpd-$web will be unlinked"
                remove_simlink
                echo "The directories related to the httpd-$web will be deleted"
                confirm
                delete_directories
                echo "The firewall will be decommissioned"
                confirm
                deactivate_firewall
                echo "Free the associated Ethernet adapter"
                confirm
                deactivate_adapter
                sleep 2
                echo "$web has been removed"
                echo ""
                echo "Running additional check.."
                updatedb
                sleep 5
                locate -i $web
                echo "Done"
                echo "----------------------------------"
                echo ""

        fi

done < web66.txt
