#!/bin/bash

set -x

# Work around systemd not giving us the environment
for e in $(tr "\000" "\n" < /proc/1/environ); do
    eval "export $e"
done

env

export MARIADB_USER=${MARIADB_USER:-"dbuser"} 
export MARIADB_PWD=${MARIADB_PWD:-"$(date +%s | sha256sum | base64 -w0 | head -c 32)"}
export MARIADB_DB=${MARIADB_DB:-"mydb"} 
export MARIADB_ROOTPWD=${MARIADB_ROOTPWD:-"$(date +%s | sha256sum | base64 -w0 | tail -c 32)"}

env

##
# Initialize Mariadb if data dir emptya
if [ "$(mysql -Be "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '${MARIADB_USER}')" | grep -v EXISTS)" == "0" ] ; then
    sh /sbin/mariadb_secure_auto.sh "${MARIADB_ROOTPWD}"
    mysql -e "CREATE DATABASE ${MARIADB_DB}"
    mysql -e "CREATE USER ${MARIADB_USER}@localhost IDENTIFIED BY '${MARIADB_PWD}'"
    mysql -e "GRANT ALL PRIVILEGES ON ${MARIADB_DB}.* TO ${MARIADB_USER}@localhost"
    printf "MARIADB_USER=\"${MARIADB_USER}\" \n MARIADB_PWD=\"${MARIADB_PWD}\" \n MARIADB_DB=\"${MARIADB_DB}\" \n MARIADB_ROOTPWD=\"${MARIADB_ROOTPWD}\" \n" > /etc/mariadb/dbauth.txt
    chmod 600 /etc/mariadb/dbauth.txt
fi

touch /etc/customize_mariadb_done
