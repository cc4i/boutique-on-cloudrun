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
    echo "Install ${svc} into Cloud Run @ ${region} ..."
    gcloud run services replace ../manifests/${svc}.yaml --region ${region}

done

# 2. Provision adjcent systems, such as Redis//


# 3. Extract related pramameters and update launched services with right parameters.

export PRODUCT_CATALOG_SERVICE_ADDR=`gcloud run services describe productcatalogservice --region asia-east2 --format "value(status.address.url)"`
echo "productcatalogservice -> ${PRODUCT_CATALOG_SERVICE_ADDR}"

export CURRENCY_SERVICE_ADDR=`gcloud run services describe currencyservice --region asia-east2 --format "value(status.address.url)"`
echo "currencyservice -> ${CURRENCY_SERVICE_ADDR}"

export CART_SERVICE_ADDR=`gcloud run services describe cartservice --region asia-east2 --format "value(status.address.url)"`
echo "cartservice -> ${CART_SERVICE_ADDR}"

export RECOMMENDATION_SERVICE_ADDR=`gcloud run services describe recommendationservice --region asia-east2 --format "value(status.address.url)"`
echo "recommendationservice -> ${RECOMMENDATION_SERVICE_ADDR}"

export SHIPPING_SERVICE_ADDR=`gcloud run services describe shippingservice --region asia-east2 --format "value(status.address.url)"`
echo "shippingservice -> ${SHIPPING_SERVICE_ADDR}"

export CHECKOUT_SERVICE_ADDR=`gcloud run services describe checkoutservice --region asia-east2 --format "value(status.address.url)"`
echo "checkoutservice -> ${CHECKOUT_SERVICE_ADDR}"

export AD_SERVICE_ADDR=`gcloud run services describe adservice --region asia-east2 --format "value(status.address.url)"`
echo "adservice -> ${AD_SERVICE_ADDR}"

export PAYMENT_SERVICE_ADDR=`gcloud run services describe paymentservice --region asia-east2 --format "value(status.address.url)"`
echo "paymentservice -> ${PAYMENT_SERVICE_ADDR}"

export EMAIL_SERVICE_ADDR=`gcloud run services describe emailservice --region asia-east2 --format "value(status.address.url)"`
echo "emailservice -> ${EMAIL_SERVICE_ADDR}"

# 4. Replace services with right envrionments
( echo "cat <<EOF" ; cat ../manifests/frontend.yaml; echo EOF ) |sh > frontend_rpl.yaml
gcloud run services replace ./frontend_rpl.yaml --region asia-east2
( echo "cat <<EOF" ; cat ../manifests/checkoutservice.yaml; echo EOF ) |sh > checkoutservice_rpl.yaml
gcloud run services replace ./checkoutservice_rpl.yaml --region asia-east2
( echo "cat <<EOF" ; cat ../manifests/recommendationservice.yaml; echo EOF ) |sh > recommendationservice_rpl.yaml
gcloud run services replace ./recommendationservice_rpl.yaml --region asia-east2
# rm *_rpl.yaml

# 5. Add 'allUsers' permission for frontend service to enable public assess.

