#!/bin/bash

set -e

export DUMP_FILE=/mnt/ebs-volume/backup_`date +%Y%m%d_%H%M%S`.pgdump
{
PGPASSWORD=$POSTGRES_PASSWORD pg_dump -Fc -d $POSTGRES_DATABASE -U $POSTGRES_USER -h $POSTGRES_HOST -f $DUMP_FILE
echo "pg_dump operation SUCCESSFULLY COMPLETED"
aws s3 cp ${DUMP_FILE} $S3_BACKUP_PATH/$RANCHER_CLUSTER_PROJECT_NAME/
echo "AWS s3 cp operation SUCCESSFULLY COMPLETED"
} ||
{
  echo "pg_dump operation FAILED (postgres backup aws s3 cp)"
}

