#!/bin/bash

(
  set -e
  export DUMP_FILE=/mnt/ebs-volume/backup_${JENKINS_BUILD_ID}-${JENKINS_START_BUILD_DATE_TIME}-${JENKINS_START_BUILD_USERNAME}
  PGPASSWORD=$DB_PASSWORD pg_dump -Fc -d $DB_DATABASE -U $DB_USERNAME -h $DB_HOST -f $DUMP_FILE
  echo "pg_dump operation SUCCESSFULLY COMPLETED"
  aws s3 cp ${DUMP_FILE} $AWS_BUCKET/$RANCHER_CLUSTER_PROJECT_NAME/
  echo "AWS s3 cp operation SUCCESSFULLY COMPLETED"
)
errorCode=$?
if [ $errorCode -ne 0 ]; then
  echo "pg_dump operation FAILED (postgres backup aws s3 cp failed)"
  exit $errorCode
fi
