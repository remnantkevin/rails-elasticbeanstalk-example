#!/bin/sh

amazon-linux-extras enable postgresql13
yum clean metadata
yum install postgresql
yum list installed postgresql
echo "from the prebuild hook"
psql --version
