# syntax=docker/dockerfile:1.5
ARG GANESHA_VERSION=4.3

FROM almalinux:9.1 as builder
ARG GANESHA_VERSION

RUN <<EOT
    dnf -y install dnf-plugins-core git gcc gcc-c++ cmake make autoconf libtool bison flex rpm-build
    dnf config-manager --set-enabled crb
    dnf -y install util-linux libblkid-devel userspace-rcu-devel libnsl2-devel libacl-devel sssd-krb5-common \
        nfs-utils dbus-devel krb5-devel libcap-devel libnfsidmap-devel libuuid-devel selinux-policy-devel
    dnf clean all
EOT

RUN adduser --system --create-home builduser
USER builduser

RUN mkdir ~/build
RUN git clone \
    --recursive \
    --depth 1 \
    --branch V${GANESHA_VERSION} \
    https://github.com/nfs-ganesha/nfs-ganesha.git \
    ~/build

WORKDIR /home/builduser/build/src
RUN cmake . \
    -D BUILD_CONFIG=rpmbuild \
    -D USE_FSAL_VFS=ON \
    -D USE_FSAL_PROXY_V4=ON \
    -D USE_FSAL_PROXY_V3=ON \
    -D USE_FSAL_LUSTRE=OFF \
    -D USE_FSAL_LIZARDFS=OFF \
    -D USE_FSAL_KVSFS=OFF \
    -D USE_FSAL_CEPH=OFF \
    -D USE_FSAL_RGW=OFF \
    -D USE_FSAL_XFS=OFF \
    -D USE_FSAL_GPFS=OFF \
    -D USE_FSAL_GLUSTER=OFF \
    -D USE_FSAL_NULL=OFF \
    -D USE_FSAL_MEM=OFF \
    -D USE_GSS=OFF \
    -D USE_9P=OFF

RUN cmake --build . --target dist

RUN <<EOF
    gunzip nfs-ganesha-${GANESHA_VERSION}.tar.gz
    tar --delete --file nfs-ganesha-${GANESHA_VERSION}.tar nfs-ganesha-${GANESHA_VERSION}/CMakeCache.txt
    cat CMakeCache.txt | grep "^USE_" > CMakeCache.txt2
    mv -f CMakeCache.txt2 CMakeCache.txt
    tar --update --file nfs-ganesha-${GANESHA_VERSION}.tar --transform "s/^/nfs-ganesha-${GANESHA_VERSION}\//" CMakeCache.txt
    gzip nfs-ganesha-${GANESHA_VERSION}.tar
EOF

RUN rpmbuild --define "_srcrpmdir ." -ts nfs-ganesha-${GANESHA_VERSION}.tar.gz

RUN rpmbuild --rebuild nfs-ganesha-${GANESHA_VERSION}-0.1.el9.src.rpm \
    --without nullfs \
    --without mem \
    --without gpfs \
    --without xfs \
    --without lustre \
    --without ceph \
    --without rgw \
    --without gluster \
    --without kvsfs \
    --without rdma \
    --without 9P \
    --without jemalloc \
    --without tcmalloc \
    --without lttng

FROM almalinux:9.1
ARG GANESHA_VERSION

COPY --from=builder --chown=root /home/builduser/rpmbuild/RPMS /rpms

WORKDIR /rpms
RUN <<EOT
    dnf -y install \
        procps-ng which dbus-daemon rpcbind nfs-utils-coreos \
        noarch/nfs-ganesha-selinux-${GANESHA_VERSION}-0.1.el9.noarch.rpm \
        x86_64/libntirpc-${GANESHA_VERSION}-0.1.el9.x86_64.rpm \
        x86_64/nfs-ganesha-${GANESHA_VERSION}-0.1.el9.x86_64.rpm \
        x86_64/nfs-ganesha-vfs-${GANESHA_VERSION}-0.1.el9.x86_64.rpm
    dnf clean all
EOT
RUN mkdir /var/run/ganesha

WORKDIR /
ENTRYPOINT ["/usr/bin/ganesha.nfsd"]
CMD ["-F", "-f", "/config.conf"]
