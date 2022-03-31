#!/bin/sh

# 1. Launch services in Cloud Run / min 10

services="adservice cartservice checkoutservice currencyservice emailservice frontend paymentservice productcatalogservice recommendationservice shippingservice"
region="asia-east2"
for svc in ${services[@]}
do
    echo "Install ${svc} into Cloud Run @ ${region} ..."
    gcloud run services replace ${svc}.yaml --region ${region}

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

# gcloud run services list --format "value(SERVICE)"
# eval "echo \"$(cat frontend.yaml)\"" > tmp.yaml 
# gcloud run services replace tmp.yaml --region asia-east2
# rm tmp.yaml