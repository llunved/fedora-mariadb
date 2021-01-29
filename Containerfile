ARG OS_RELEASE=33
ARG OS_IMAGE=fedora:$OS_RELEASE

FROM $OS_IMAGE as build

ARG OS_RELEASE
ARG OS_IMAGE
ARG HTTP_PROXY=""

LABEL MAINTAINER riek@llunved.net

ENV LANG=C.UTF-8

ENV VOLUMES="/etc/mariadb,/var/lib/mysql,/usr/share/doc/mariadb,/var/log/mariadb"

USER root

RUN mkdir -p /mariadb
WORKDIR /mariadb

ADD ./rpmreqs-build.txt /mariadb/

ENV http_proxy=$HTTP_PROXY
RUN dnf -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$OS_RELEASE.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$OS_RELEASE.noarch.rpm \
    && dnf -y upgrade \
    && dnf -y install $(cat rpmreqs-build.txt) 

ADD ./rpmreqs-rt.txt ./rpmreqs-dev.txt /mariadb/
# Create the minimal target environment
RUN mkdir /sysimg \
    && dnf install --installroot /sysimg --releasever $OS_RELEASE --setopt install_weak_deps=false --nodocs -y coreutils-single glibc-minimal-langpack $(cat rpmreqs-rt.txt) \
    && if [ ! -n "${DEVBUILD}" ]; then dnf install --installroot /sysimg --releasever $OS_RELEASE --setopt install_weak_deps=false --nodocs -y $(cat rpmreqs-dev.txt); fi \
    && rm -rf /sysimg/var/cache/*

#FIXME this needs to be more elegant
RUN cp -v /sysimg/usr/share/zoneinfo/America/New_York /sysimg/etc/localtime

# Move the mariadb config to a doc dir, so we can mount config from the host but export the defaults from the host
RUN if [ -d /sysimg/usr/share/doc/mariadb ]; then \
       mv /sysimg/usr/share/doc/mariadb /sysimg/usr/share/doc/mariadb.default ; \
    else \
       mkdir -pv /sysimg/usr/share/doc/mariadb.default ; \
    fi ; \
    mkdir -pv /sysimg/usr/share/doc/mariadb.default/config

RUN mkdir /sysimg/etc/mariadb && \
    mv -fv /sysimg/etc/my.cnf /sysimg/etc/my.cnf.d /sysimg/etc/mariadb && \
    ln -srfv /sysimg/etc/mariadb/my.cnf /sysimg/etc/my.cnf && \
    ln -srfv /sysimg/etc/mariadb/my.cnf.d /sysimg/etc/my.cnf.d 
   
RUN for CURF in $(tr ',' '\n' <<< "${VOLUMES}") ; do \
        if [ -d /sysimg${CURF} ] && [ "$(ls -A /sysimg${CURF})" ]; then \
            mkdir -pv /sysimg/usr/share/doc/mariadb.default/config${CURF} ; \
            mv -fv /sysimg${CURF}/* /sysimg/usr/share/doc/mariadb.default/config${CURF}/ ;\
        fi ; \
    done

# Set up systemd inside the container
ADD init_container.service chown_dirs.service customize_mariadb.service /sysimg/etc/systemd/system
RUN systemctl --root /sysimg mask systemd-remount-fs.service dev-hugepages.mount sys-fs-fuse-connections.mount systemd-logind.service getty.target console-getty.service && systemctl --root /sysimg disable dnf-makecache.timer dnf-makecache.service
RUN /usr/bin/systemctl --root /sysimg enable mariadb.service init_container.service chown_dirs.service customize_mariadb.service



FROM scratch AS runtime

COPY --from=build /sysimg /

WORKDIR /var/lib/mysql

ENV VOLUMES="/etc/mariadb,/var/lib/mysql,/usr/share/doc/mariadb,/var/log/mariadb"
ENV CHOWN_USER="mysql"
ENV CHOWN=true 
ENV CHOWN_DIRS="/var/lib/mysql,/var/log/mariadb"

VOLUME /etc/mariadb
VOLUME /var/lib/mysql
VOLUME /usr/share/doc/mariadb
VOLUME /var/log/mariadb

ADD ./mariadb_secure_auto.sh \
    ./init_container.sh \
    ./customize_mariadb.sh \
    ./chown_dirs.sh \
    /sbin
 
RUN chmod +x /sbin/mariadb_secure_auto.sh \
             /sbin/init_container.sh \
             /sbin/customize_mariadb.sh \
             /sbin/chown_dirs.sh
  
EXPOSE 3306 33060
CMD ["/usr/sbin/init"]
STOPSIGNAL SIGRTMIN+3

#FIXME - BROKE THESE WITH THE MOVE TO PODS
#LABEL RUN="podman run --rm -t -i --name ${NAME} --net=host -v /var/lib/${NAME}/www:/var/www:rw,z -v etc/${NAME}:/etc/${NAME}:rw,z -v /var/log/${NAME}:/var/log/${NAME}:rw,z ${IMAGE}"
#LABEL INSTALL="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/install.sh"
#LABEL UPGRADE="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/upgrade.sh"
#LABEL UNINSTALL="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/uninstall.sh"

