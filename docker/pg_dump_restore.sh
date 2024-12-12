#!/bin/bash
set -e
echo "${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}.sql"
echo "${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_DATA}.tar"
echo "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.sql"
echo "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_DATA}.tar"
echo "$(pwd)"
aws --region us-west-2 s3 cp "s3://${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}.sql" "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.sql"
echo "AWS s3 cp operation of file ${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}.sql to ${EBS_VOLUME_MOUNT_PATH} path SUCCESSFULLY COMPLETED"
aws --region us-west-2 s3 cp "s3://${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_DATA}.tar" "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_DATA}.tar"
echo "AWS s3 cp operation of file ${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_DATA}.tar to ${EBS_VOLUME_MOUNT_PATH} path SUCCESSFULLY COMPLETED"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USERNAME -p $DB_PORT --dbname="folio" -a -f "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.sql"
echo "psql restore operation SUCCESSFULLY COMPLETED. Path to file is ${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.sql"
PGPASSWORD=$DB_PASSWORD pg_restore -h $DB_HOST -U $DB_USERNAME -p $DB_PORT --dbname="folio" --verbose --format="tar" --exit-on-error "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_DATA}.tar"
echo "pg_restore operation SUCCESSFULLY COMPLETED. Path to file is ${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_DATA}.tar"
errorCode=$?
if [ $errorCode -ne 0 ]; then
  echo "psql restore operation FAILED (postgres restore aws s3 cp failed)"
  exit $errorCode