#!/bin/bash

(
  set -e
  export DUMP_FILE=/mnt/ebs-volume/${JENKINS_DB_BACKUP_NAME}
  PGPASSWORD=$DB_PASSWORD pg_dump -Fc -d $DB_DATABASE -U $DB_USERNAME -h $DB_HOST -f $DUMP_FILE
  echo "pg_dump operation SUCCESSFULLY COMPLETED. Path to file is $DUMP_FILE"
  aws s3 cp ${DUMP_FILE} $AWS_BUCKET/$RANCHER_CLUSTER_PROJECT_NAME/
  echo "AWS s3 cp operation of file $DUMP_FILE SUCCESSFULLY COMPLETED"
)
errorCode=$?
if [ $errorCode -ne 0 ]; then
  echo "pg_dump operation FAILED (postgres backup aws s3 cp failed)"
  exit $errorCode
fi
