#!/bin/bash

amazon-linux-extras enable postgresql13
yum clean metadata
yum install postgresql
yum list installed postgresql
psql --version
