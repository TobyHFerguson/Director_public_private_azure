#!/bin/bash

# Declare directory structure
PARCELS_DIR=cdh5/parcels
VERSION_DIR=${PARCELS_DIR:?}/5.15

ARCHIVE=https://archive.cloudera.com
CDH_URL=${ARCHIVE:?}/${VERSION_DIR:?}

HTML_DIR=/var/www/html
CDH5_REPO_DIR=${HTML_DIR:?}/${VERSION_DIR:?}

RPM_DIR=centos/RPMS
CENTOS_PACKAGE_DIR=${HTML_DIR:?}/${RPM_DIR}

# Install needed packages
yum -y --quiet install httpd yum-utils createrepo
systemctl enable httpd
systemctl start httpd

# Start creating everything
mkdir -p ${CDH5_REPO_DIR:?}
mkdir -p ${CENTOS_PACKAGE_DIR:?}

# Figure out the latest parcel
PARCEL=$(curl --silent ${CDH_URL:?}/ | sed -n 's/.*\(CDH-.*el7.parcel\).*/\1/p' | sort | head -1)

# Install/update the parcel in the REPO_DIR
(
    cd ${CDH5_REPO_DIR:?}
    [ -f ${PARCEL:?} ] || curl --silent -O ${CDH_URL:?}/${PARCEL:?}
    [ -f manifest.json ] || curl --silent -O ${CDH_URL:?}/manifest.json
    [ -f ${PARCEL:?}.sha1 ] || curl --silent -O ${CDH_URL:?}/${PARCEL:?}.sha1
)

(
    cd ${CENTOS_PACKAGE_DIR:?}
    repotrack screen ntp curl nscd python gdisk
    cd ..
    createrepo .
)

