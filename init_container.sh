#!/bin/bash

set -x
OS_IMAGE=${OS_IMAGE:-"registry.fedoraproject.org/fedora:${OS_RELEASE}"}
OS_RELEASE=${OS_RELEASE:-$(grep VERSION_ID /etc/os-release | cut -d '=' -f 2)}

MARIADB_USER=${MARIADB_USER:-"nextcloud"} 
MARIADB_PWD=${MARIADB_PWD:-"$(date +%s | sha256sum | base64 | head -c 32)"}
MARIADB_DB=${MARIADB_DB:-"nextcloud"} 
MARIADB_ROOTPWD=${MARIADB_ROOTPWD:-"$(date +%s | sha256sum | base64 | tail -c 32)"}

env

##
# Copy default config files to mounted volumes

# Make sure that we have required directories in the host

cp -pRuv /usr/share/doc/mariadb.default/* /usr/share/doc/mariadb/

# Initialize Mariadb if data dir emptya
if [ "$(mysql -Be "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '${MARIADB_USER}')" | grep -v EXISTS)" == "0" ] ; then
    sh /sbin/mariadb_secure_auto.sh "${MARIADB_ROOTPWD}"
    mysql -e "CREATE DATABASE ${MARIADB_DB}"
    mysql -e "GRANT ALL PRIVILEGES ON ${MARIADB_DB}.* TO ${MARIADB_USER}@localhost IDENTIFIED BY '${MARIADB_PWD}!'"
    echo "MARIADB_USER=${MARIADB_USER} \n MARIADB_PWD=${MARIADB_PWD} \n MARIADB_DB=${MARIADB_DB} \n MARIADB_ROOTPWD=${MARIADB_ROOTPWD} \n" > /etc/mariadb/dbauth.txt
    chmod 600 /etc/mariadb/dbauth.txt
fi

for CUR_DIR in ${VOLUMES} ; do
    if [ -d ${CUR_DIR} ]; then
        if [ -f ${CUR_DIR}/.forceinit ] || [ ! "$(ls -A ${CUR_DIR}/)" ]; then
            if [ -d /usr/share/doc/mariadb.default/config${CUR_DIR} ]; then
                cp -pRv /usr/share/doc/mariadb.default/config${CUR_DIR}/* ${CUR_DIR}/
            fi
        fi
    fi 
done

touch /etc/init_done
