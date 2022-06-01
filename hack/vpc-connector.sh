#!/bin/sh

export REGION=$1
export VPC_NETWORK=$2
export SERVERLESS_CONNECTOR=$3

if [ -z "${REGION}" ]
then
    echo "{REGION} is not defined."
    exit 1
fi

if [ -z "${VPC_NETWORK}" ]
then
    echo "{VPC_NETWORK} is not defined."
    exit 1
fi

if [ -z "${SERVERLESS_CONNECTOR}" ]
then
    echo "{SERVERLESS_CONNECTOR} is not defined."
    exit 1
fi

state=`gcloud compute networks vpc-access connectors describe ${SERVERLESS_CONNECTOR} --region ${REGION} --format="value('state')" || true`
if [ "${state}"="READY" ]
then
    echo "VPC access connector ${SERVERLESS_CONNECTOR} is ready."
    echo ""
else
    # VPC_NETWORK -> Name of VPC
    echo "Enable VPC access API."
    gcloud services enable vpcaccess.googleapis.com

    echo "Creating VPC access connector...${SERVERLESS_CONNECTOR}"
    gcloud compute networks vpc-access connectors create ${SERVERLESS_CONNECTOR} \
        --network ${VPC_NETWORK} \
        --region ${REGION} \
        --range 10.8.0.0/28
    echo "Done."
fi
