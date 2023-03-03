#!/bin/bash

if [ "$ACTION" == backup ]; then
  (
    set -e
    PGPASSWORD=${DB_PASSWORD} pg_dumpall -h ${DB_HOST} -U ${DB_USERNAME} -p ${DB_PORT} -l ${DB_DATABASE} \
    -f "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.psql"
    echo "pg_dumpall operation SUCCESSFULLY COMPLETED. Path to file is ${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.psql"
    aws s3 cp "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.psql" "${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}/"
    echo "AWS s3 cp operation of file ${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.psql to s3 ${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}/ bucket SUCCESSFULLY COMPLETED"
    okapiToken=$(curl -X POST https://${RANCHER_CLUSTER_NAME}-${RANCHER_PROJECT_NAME}-okapi.ci.folio.org/authn/login -H "Content-Type: application/json" -H "X-Okapi-Tenant: ${TENANT}" -d '{"username": "'"${TENANT_ADMIN_USERNAME}"'", "password": "'"${TENANT_ADMIN_PASSWORD}"'"}' | jq '.okapiToken' -r)
    echo "SUCCESSFULLY got okapiToken for tenant - $TENANT, adminUser - $TENANT_ADMIN_USERNAME, environment - https://${RANCHER_CLUSTER_NAME}-${RANCHER_PROJECT_NAME}-okapi.ci.folio.org/authn/login"
    installedModules=$(curl -X GET https://${RANCHER_CLUSTER_NAME}-${RANCHER_PROJECT_NAME}-okapi.ci.folio.org/_/proxy/tenants/${TENANT}/modules  -H "Content-Type: application/json" -H "X-Okapi-Tenant: ${TENANT}" -H "X-Okapi-Token: ${okapiToken}")
    echo "SUCCESSFULLY got list of installedModules for tenant - $TENANT, adminUser - $TENANT_ADMIN_USERNAME, environment - https://${RANCHER_CLUSTER_NAME}-${RANCHER_PROJECT_NAME}-okapi.ci.folio.org/authn/login"
    jq '.[] | . += { "action": "enable" }' <<<"$installedModules" | jq '.' -s > "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}-install.json"
    aws s3 cp "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}-install.json" "${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}/"
    echo "AWS s3 cp operation of file ${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}-install.json to s3 ${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}/ bucket SUCCESSFULLY COMPLETED"
  )
  errorCode=$?
  if [ $errorCode -ne 0 ]; then
    echo "pg_dump operation FAILED (postgres backup aws s3 cp failed)"
    exit $errorCode
  fi
elif [ "$ACTION" == restore ]; then
  (
    set -e
    aws s3 cp "${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}/${DB_BACKUP_NAME}.psql" "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.psql"
    echo "AWS s3 cp operation of file ${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}/${DB_BACKUP_NAME}.psql to ${EBS_VOLUME_MOUNT_PATH} path SUCCESSFULLY COMPLETED"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USERNAME -p $DB_PORT < "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.psql" >> "${EBS_VOLUME_MOUNT_PATH}/import.log"
    echo "psql restore operation SUCCESSFULLY COMPLETED. Path to file is ${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.psql"
    )
    errorCode=$?
    if [ $errorCode -ne 0 ]; then
      echo "psql restore operation FAILED (postgres restore aws s3 cp failed)"
      exit $errorCode
    fi
elif [ "$ACTION" == rds_backup ]; then
  (
    set -e
    echo "Start backup"

    PGPASSWORD=${TEMPORARY_RDS_PASSWORD} pg_dumpall --globals-only --no-role-passwords \
    -h ${TEMPORARY_RDS_HOST} -U ${TEMPORARY_RDS_USERNAME} -p ${TEMPORARY_RDS_PORT} -l ${TEMPORARY_RDS_DATABASE} \
    -f "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}-globals.psql"

    PGPASSWORD=${TEMPORARY_RDS_PASSWORD} pg_dump -Z0 -j 5 -Fd  \
    -h ${TEMPORARY_RDS_HOST} -U ${TEMPORARY_RDS_USERNAME} -p ${TEMPORARY_RDS_PORT} -d ${TEMPORARY_RDS_DATABASE} \
    -f "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}-dir"

    tar -cf "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.tar" "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}-dir"

    echo "pg_dumpall operation SUCCESSFULLY COMPLETED. Path to file is ${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.psql"
    aws s3 cp "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}-globals.psql" "${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}/"
    aws s3 cp "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.tar" "${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}/"
    echo "AWS s3 cp operation of file ${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.psql to s3 ${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}/ bucket SUCCESSFULLY COMPLETED"
    )
  errorCode=$?
  if [ $errorCode -ne 0 ]; then
    echo "pg_dump operation FAILED (postgres backup aws s3 cp failed)"
    exit $errorCode
  fi
elif [ "$ACTION" == rds_restore ]; then
  (
    set -e
    echo "Start backup"

    aws s3 cp "${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}/${DB_BACKUP_NAME}-globals.psql" "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}-globals.psql"
    aws s3 cp "${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}/${DB_BACKUP_NAME}.tar" "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.tar"
    echo "AWS s3 cp operation of file ${S3_BACKUPS_BUCKET}/${S3_BACKUPS_DIRECTORY}/${DB_BACKUP_NAME}/${DB_BACKUP_NAME}.psql to ${EBS_VOLUME_MOUNT_PATH} path SUCCESSFULLY COMPLETED"

    tar -xvf "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.tar"

    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USERNAME -p $DB_PORT < "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}-globals.psql" >> "${EBS_VOLUME_MOUNT_PATH}/globals-import.log"
    #schema-only
    PGPASSWORD=$DB_PASSWORD pg_restore -j 5 -Fd -vvv -h $DB_HOST -U $DB_USERNAME -p $DB_PORT -d "${TEMPORARY_RDS_DATABASE}" "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}-dir" >> "${EBS_VOLUME_MOUNT_PATH}/import.log"
    #data-only
    PGPASSWORD=$DB_PASSWORD pg_restore -j 5 -Fd -vvv -a -h $DB_HOST -U $DB_USERNAME -p $DB_PORT -d "${TEMPORARY_RDS_DATABASE}" "${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}-dir" >> "${EBS_VOLUME_MOUNT_PATH}/data-import.log"
    echo "psql restore operation SUCCESSFULLY COMPLETED. Path to file is ${EBS_VOLUME_MOUNT_PATH}/${DB_BACKUP_NAME}.psql"

    )
  errorCode=$?
  if [ $errorCode -ne 0 ]; then
    echo "pg_dump operation FAILED (postgres backup aws s3 cp failed)"
    exit $errorCode
  fi
fi

