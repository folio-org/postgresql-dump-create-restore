#!/bin/bash

export DUMP_FILE=/mnt/ebs-volume/backup_`date +%Y%m%d_%H%M%S`.pgdump
PGPASSWORD=$POSTGRES_PASSWORD pg_dump -Fc -d $POSTGRES_DB -U $POSTGRES_USER -h $POSTGRES_HOST -f $DUMP_FILE
echo "pg_dump operation SUCCESSFULLY COMPLETED"
aws s3 cp ${DUMP_FILE} $S3_BACKUP_PATH
echo "AWS s3 cp operation SUCCESSFULLY COMPLETED"