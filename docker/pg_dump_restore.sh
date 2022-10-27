#!/bin/bash

if [ "$ACTION" == backup ]; then
  (
    set -e
    PGPASSWORD=$DB_PASSWORD pg_dumpall -h $DB_HOST -U $DB_USERNAME -p $DB_PORT -l $DB_DATABASE \
    -f $EBS_VOLUME_MOUNT_PATH/$JENKINS_DB_BACKUP_NAME.psql
    echo "pg_dumpall operation SUCCESSFULLY COMPLETED. Path to file is $EBS_VOLUME_MOUNT_PATH/$JENKINS_DB_BACKUP_NAME.psql"
    aws s3 cp $EBS_VOLUME_MOUNT_PATH/$JENKINS_DB_BACKUP_NAME.psql $AWS_BUCKET/$RANCHER_CLUSTER_NAME/$RANCHER_PROJECT_NAME/$JENKINS_DB_BACKUP_NAME/
    echo "AWS s3 cp operation of file $EBS_VOLUME_MOUNT_PATH/$JENKINS_DB_BACKUP_NAME.psql to s3 $AWS_BUCKET/$RANCHER_CLUSTER_NAME/$RANCHER_PROJECT_NAME/$JENKINS_DB_BACKUP_NAME/ bucket SUCCESSFULLY COMPLETED"
    okapiToken=$(curl -X POST https://${RANCHER_CLUSTER_NAME}-${RANCHER_PROJECT_NAME}-okapi.ci.folio.org/authn/login -H "Content-Type: application/json" -H "X-Okapi-Tenant: ${TENANT}" -d '{"username": "'"${TENANT_ADMIN_USERNAME}"'", "password": "'"${TENANT_ADMIN_PASSWORD}"'"}' | jq '.okapiToken' -r)
    echo "SUCCESSFULLY got okapiToken for tenant - $TENANT, adminUser - $TENANT_ADMIN_USERNAME, environment - https://${RANCHER_CLUSTER_NAME}-${RANCHER_PROJECT_NAME}-okapi.ci.folio.org/authn/login"
    installedModules=$(curl -X GET https://${RANCHER_CLUSTER_NAME}-${RANCHER_PROJECT_NAME}-okapi.ci.folio.org/_/proxy/tenants/diku/modules  -H "Content-Type: application/json" -H "X-Okapi-Tenant: ${TENANT}" -H "X-Okapi-Token: ${okapiToken}")
    echo "SUCCESSFULLY got list of installedModules for tenant - $TENANT, adminUser - $TENANT_ADMIN_USERNAME, environment - https://${RANCHER_CLUSTER_NAME}-${RANCHER_PROJECT_NAME}-okapi.ci.folio.org/authn/login"
    jq '.[] | . += { "action": "enable" }' <<<"$installedModules" | jq '.' -s > $EBS_VOLUME_MOUNT_PATH/"$JENKINS_DB_BACKUP_NAME"_install.json
    aws s3 cp $EBS_VOLUME_MOUNT_PATH/"$JENKINS_DB_BACKUP_NAME"_install.json $AWS_BUCKET/$RANCHER_CLUSTER_NAME/$RANCHER_PROJECT_NAME/$JENKINS_DB_BACKUP_NAME/
    echo "AWS s3 cp operation of file $EBS_VOLUME_MOUNT_PATH/"$JENKINS_DB_BACKUP_NAME"_install.json to s3 $AWS_BUCKET/$RANCHER_CLUSTER_NAME/$RANCHER_PROJECT_NAME/$JENKINS_DB_BACKUP_NAME/ bucket SUCCESSFULLY COMPLETED"
    jq 'map( select(.id | test("okapi-.*") | not)) | map( select(.id | test("folio_.*") | not)) | map( select(.id | test("edge-.*") | not)) | .[] | . += { "action": "enable" }' <<<"$installedModules" | jq '.' -s > $EBS_VOLUME_MOUNT_PATH/"$JENKINS_DB_BACKUP_NAME"_okapi_install.json
    aws s3 cp $EBS_VOLUME_MOUNT_PATH/"$JENKINS_DB_BACKUP_NAME"_okapi_install.json $AWS_BUCKET/$RANCHER_CLUSTER_NAME/$RANCHER_PROJECT_NAME/$JENKINS_DB_BACKUP_NAME/
    echo "AWS s3 cp operation of file $EBS_VOLUME_MOUNT_PATH/"$JENKINS_DB_BACKUP_NAME"_okapi_install.json to s3 $AWS_BUCKET/$RANCHER_CLUSTER_NAME/$RANCHER_PROJECT_NAME/$JENKINS_DB_BACKUP_NAME/ bucket SUCCESSFULLY COMPLETED"
  )
  errorCode=$?
  if [ $errorCode -ne 0 ]; then
    echo "pg_dump operation FAILED (postgres backup aws s3 cp failed)"
    exit $errorCode
  fi
elif [ "$ACTION" == restore ]; then
  (
    set -e
    aws s3 cp "$AWS_BUCKET/$JENKINS_DB_BACKUP_NAME/$JENKINS_DB_BACKUP_NAME.psql" "$EBS_VOLUME_MOUNT_PATH/$JENKINS_DB_BACKUP_NAME/$JENKINS_DB_BACKUP_NAME.psql"
    echo "AWS s3 cp operation of file $AWS_BUCKET/$JENKINS_DB_BACKUP_NAME/$JENKINS_DB_BACKUP_NAME.psql to $EBS_VOLUME_MOUNT_PATH path SUCCESSFULLY COMPLETED"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USERNAME -p $DB_PORT < "$EBS_VOLUME_MOUNT_PATH/$JENKINS_DB_BACKUP_NAME/$JENKINS_DB_BACKUP_NAME.psql" > /dev/null
    echo "psql restore operation SUCCESSFULLY COMPLETED. Path to file is $EBS_VOLUME_MOUNT_PATH/$JENKINS_DB_BACKUP_NAME/$JENKINS_DB_BACKUP_NAME.psql"
    )
    errorCode=$?
    if [ $errorCode -ne 0 ]; then
      echo "psql restore operation FAILED (postgres restore aws s3 cp failed)"
      exit $errorCode
    fi
fi

