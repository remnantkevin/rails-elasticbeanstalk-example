#!/bin/sh

echo "------- START: 02_use_correct_procfile.sh -------"

IS_WORKER=$(/opt/elasticbeanstalk/bin/get-config environment -k IS_WORKER)

echo "IS_WORKER"
echo $IS_WORKER

if [ $IS_WORKER == true ]; then
  mv Procfile.worker Procfile
else
  mv Procfile.web Procfile
fi

echo "------- END: 02_use_correct_procfile.sh -------"
