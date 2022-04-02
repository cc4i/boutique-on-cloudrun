#!/bin/sh

# 0. Based environment variables
export PROJECT_ID=play-with-anthos-340801
export REGION=asia-east2
export SERVERLESS_CONNECTOR=vpc-connector-cloudrun

# 1. Launch services in Cloud Run / min 10

services="adservice cartservice checkoutservice currencyservice emailservice frontend paymentservice productcatalogservice recommendationservice shippingservice"
region=${REGION}
for svc in ${services[@]}
do
    echo "Deleting ${svc} from Cloud Run @ ${region} ..."
    gcloud run services delete ${svc} --region ${region} --async --quiet

done