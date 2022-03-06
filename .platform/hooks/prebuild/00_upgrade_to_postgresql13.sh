#!/bin/sh

echo "------- START: 00_upgrade_to_postgresql13.sh -------"

echo "Running command amazon-linux-extras enable postgresql13"
amazon-linux-extras enable postgresql13 > /dev/null 2>&1

echo "Running command yum clean metadata"
yum clean metadata

echo "Running command yum install postgresql --assumeyes"
yum install postgresql --assumeyes

echo "Running command yum list installed postgresql"
yum list installed postgresql

echo "Running command psql --version"
psql --version

echo "------- END: 00_upgrade_to_postgresql13.sh -------"
