#!/bin/sh


export REGION=$1
export INSTANCE_NAME=$2

if [ -z "${REGION}" ]
then
	echo "{REGION} is not defined."
	exit 1
fi

if [ -z "${INSTANCE_NAME}" ]
then
	echo "{INSTANCE_NAME} is not defined."
	exit 1
fi

state=`gcloud redis instances describe ${INSTANCE_NAME} --region=${REGION} --format="value('state')" || true`
if [ "${state}"="READY" ]
then
	echo "Redis instance ${INSTANCE_NAME} is ready."
	echo ""
else
echo "Creating Redis instance ... ${INSTANCE_NAME}"
gcloud redis instances create ${INSTANCE_NAME} \
	--size=2 "--region="${REGION} \
	--redis-version=redis_6_x
echo "Done."
fi
