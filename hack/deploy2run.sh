#!/bin/sh
set -x 

# 0. Based environment variables
if [ -z "${project_id}" ]
then
    echo "{project_id} is not defined."
    exit 1
fi
if [ -z "${region}" ]
then
    echo "{region} is not defined."
    exit 1
fi
if [ -z "${vpc_network}" ]
then
    echo "{vpc_network} is not defined."
    exit 1
fi
if [ -z "${serverless_connector}" ]
then
    echo "{serverless_connector} is not defined."
    exit 1
fi
if [ -z "${redis_instance_name}" ]
then
    echo "{redis_instance_name} is not defined."
    exit 1
fi
export PROJECT_ID=${project_id}
export REGION=${region}
export VPC_NETWORK=${vpc_network}
export SERVERLESS_CONNECTOR=${serverless_connector}
export REDIS_INSTANCE_NAME=${redis_instance_name}

# 1. Retrieve info of adjcent systems, such as Redis//
export REDIS_HOST=`gcloud redis instances describe ${REDIS_INSTANCE_NAME} --region ${region} --format="value('host')"`
export REDIS_PORT=`gcloud redis instances describe ${REDIS_INSTANCE_NAME} --region ${region} --format="value('port')"`

# 2. Build/Push image into Artifact Registry by skaffold & retrieve /image:tag/
cd ../demo
skaffold build
for image in `skaffold build --dry-run --output='{{json .}}' --quiet |jq '.builds[].tag' -r`
do 
    echo ${image}
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
        *shippingservice*)
            export shippingservice="${image}"
            echo ${shippingservice}
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
echo `pwd`


# 3. Launch services in Cloud Run / min 10
run_services="adservice cartservice checkoutservice currencyservice emailservice frontend paymentservice productcatalogservice recommendationservice shippingservice"
for svc in `echo ${run_services}`
do
    echo "Install ${svc} into Cloud Run @ ${region} ..."
    ( echo "cat <<EOF" ; cat ../manifests/${svc}.yaml; echo EOF ) |sh > /tmp/${svc}_rpl.yaml
    gcloud run services replace /tmp/${svc}_rpl.yaml --region ${region}
    rm -f /tmp/${svc}_rpl.yaml

done


# 4. Extract related pramameters and update launched services with right parameters.
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

# 5. Replace services with right envrionments
( echo "cat <<EOF" ; cat ../manifests/cartservice.yaml; echo EOF ) |sh > /tmp/cartservice_rpl.yaml
gcloud run services replace /tmp/cartservice_rpl.yaml --region ${region}

( echo "cat <<EOF" ; cat ../manifests/frontend.yaml; echo EOF ) |sh > /tmp/frontend_rpl.yaml
gcloud run services replace /tmp/frontend_rpl.yaml --region ${region}

( echo "cat <<EOF" ; cat ../manifests/checkoutservice.yaml; echo EOF ) |sh > /tmp/checkoutservice_rpl.yaml
gcloud run services replace /tmp/checkoutservice_rpl.yaml --region ${region}

( echo "cat <<EOF" ; cat ../manifests/recommendationservice.yaml; echo EOF ) |sh > /tmp/recommendationservice_rpl.yaml
gcloud run services replace /tmp/recommendationservice_rpl.yaml --region ${region}


# 6. Add 'allUsers' permission for frontend service to enable public assess.
gcloud run services add-iam-policy-binding frontend \
    --member=allUsers \
    --role=roles/run.invoker \
    --region=${region}
