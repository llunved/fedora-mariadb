#!/bin/bash

set -x

# Work around systemd not giving us the environment
for e in $(tr "\000" "\n" < /proc/1/environ); do
    eval "export $e"
done

env

##
# Copy default config files to mounted volumes

cp -pRuv /usr/share/doc/mariadb.default/* /usr/share/doc/mariadb/

for CUR_DIR in $(tr ',' '\n' <<< "${VOLUMES}") ; do
    echo "(${CUR_DIR})"
    if [ -d ${CUR_DIR} ]; then
        if [ -f ${CUR_DIR}/.forceinit ] || [ ! "$(ls -A ${CUR_DIR}/)" ]; then
            if [ -d /usr/share/doc/mariadb.default/config${CUR_DIR} ]; then
                cp -pRv /usr/share/doc/mariadb.default/config${CUR_DIR}/* ${CUR_DIR}/
            fi
	    [ -f ${CUR_DIR}/.forceinit ] && rm -fv ${CUR_DIR}/.forceinit
        fi
    fi 
done

touch /etc/init_done
