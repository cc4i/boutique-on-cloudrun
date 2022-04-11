#!/bin/sh

# 0. Based environment variables
export PROJECT_ID=play-with-anthos-340801
export REGION=${region}
export SERVERLESS_CONNECTOR=vpc-connector-cloudrun

# 1. Provision adjcent systems, such as Redis//
# 1.1 Launch a Redis cluster if not existed
export REDIS_HOST=`gcloud redis instances describe redis4cart --region ${region} --format="value('host')"`
export REDIS_PORT=`gcloud redis instances describe redis4cart --region ${region} --format="value('port')"`

# 1.2 Build/Push image into Artifact Registry by skaffold & retrieve /image:tag/
cd ../demo
skaffold build
for image in `skaffold build --dry-run --output='{{json .}}' --quiet |jq '.builds[].tag' -r`
do 
    
    case ${image} in
        *emailservice*)
            export emailservice="${image}"
            echo ${emailservice}
            ;;
        *productcatalogservice*)
            export productcatalogservice="${image}"
            echo ${productcatalogservice}
            ;;
        *recommendationservice*)
            export recommendationservice="${image}"
            echo ${recommendationservice}
            ;;
        *checkoutservice*)
            export checkoutservice="${image}"
            echo ${checkoutservice}
            ;;
        *paymentservice*)
            export paymentservice="${image}"
            echo ${paymentservice}
            ;;
        *currencyservice*)
            export currencyservice="${image}"
            echo ${currencyservice}
            ;;
        *cartservice*)
            export cartservice="${image}"
            echo ${cartservice}
            ;;
        *frontend*)
            export frontend="${image}"
            echo ${frontend}
            ;;
        *adservice*)
            export adservice="${image}"
            echo ${adservice}
            ;;
    esac
done
cd -

# 2. Launch services in Cloud Run / min 10

services="adservice cartservice checkoutservice currencyservice emailservice frontend paymentservice productcatalogservice recommendationservice shippingservice"
region=${REGION}
for svc in ${services[@]}
do
    echo "Install ${svc} into Cloud Run @ ${region} ..."
    ( echo "cat <<EOF" ; cat ../manifests/${svc}.yaml; echo EOF ) |sh > /tmp/${svc}_rpl.yaml
    gcloud run services replace /tmp/${svc}_rpl.yaml --region ${region}

done



# 3. Extract related pramameters and update launched services with right parameters.
prefix="https://"
url=`gcloud run services describe productcatalogservice --region ${region} --format "value(status.address.url)"`
export PRODUCT_CATALOG_SERVICE_ADDR=${url#"$prefix"}
echo "productcatalogservice -> ${PRODUCT_CATALOG_SERVICE_ADDR}"

url=`gcloud run services describe currencyservice --region ${region} --format "value(status.address.url)"`
export CURRENCY_SERVICE_ADDR=${url#"$prefix"}
echo "currencyservice -> ${CURRENCY_SERVICE_ADDR}"

url=`gcloud run services describe cartservice --region ${region} --format "value(status.address.url)"`
export CART_SERVICE_ADDR=${url#"$prefix"}
echo "cartservice -> ${CART_SERVICE_ADDR}"

url=`gcloud run services describe recommendationservice --region ${region} --format "value(status.address.url)"`
export RECOMMENDATION_SERVICE_ADDR=${url#"$prefix"}
echo "recommendationservice -> ${RECOMMENDATION_SERVICE_ADDR}"

url=`gcloud run services describe shippingservice --region ${region} --format "value(status.address.url)"`
export SHIPPING_SERVICE_ADDR=${url#"$prefix"}
echo "shippingservice -> ${SHIPPING_SERVICE_ADDR}"

url=`gcloud run services describe checkoutservice --region ${region} --format "value(status.address.url)"`
export CHECKOUT_SERVICE_ADDR=${url#"$prefix"}
echo "checkoutservice -> ${CHECKOUT_SERVICE_ADDR}"

url=`gcloud run services describe adservice --region ${region} --format "value(status.address.url)"`
export AD_SERVICE_ADDR=${url#"$prefix"}
echo "adservice -> ${AD_SERVICE_ADDR}"

url=`gcloud run services describe paymentservice --region ${region} --format "value(status.address.url)"`
export PAYMENT_SERVICE_ADDR=${url#"$prefix"}
echo "paymentservice -> ${PAYMENT_SERVICE_ADDR}"

url=`gcloud run services describe emailservice --region ${region} --format "value(status.address.url)"`
export EMAIL_SERVICE_ADDR=${url#"$prefix"}
echo "emailservice -> ${EMAIL_SERVICE_ADDR}"

# 4. Replace services with right envrionments
( echo "cat <<EOF" ; cat ../manifests/cartservice.yaml; echo EOF ) |sh > /tmp/cartservice_rpl.yaml
gcloud run services replace /tmp/cartservice_rpl.yaml --region ${region}

( echo "cat <<EOF" ; cat ../manifests/frontend.yaml; echo EOF ) |sh > /tmp/frontend_rpl.yaml
gcloud run services replace /tmp/frontend_rpl.yaml --region ${region}

( echo "cat <<EOF" ; cat ../manifests/checkoutservice.yaml; echo EOF ) |sh > /tmp/checkoutservice_rpl.yaml
gcloud run services replace /tmp/checkoutservice_rpl.yaml --region ${region}

( echo "cat <<EOF" ; cat ../manifests/recommendationservice.yaml; echo EOF ) |sh > /tmp/recommendationservice_rpl.yaml
gcloud run services replace /tmp/recommendationservice_rpl.yaml --region ${region}


# 5. Add 'allUsers' permission for frontend service to enable public assess.

