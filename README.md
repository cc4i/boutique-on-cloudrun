# Boutique on Cloud Run

The project is to demostrate how to migrate Kubernetes application into Cloud Run in order to leverage the power of serverless computing. The demo application was forked from https://github.com/GoogleCloudPlatform/microservices-demo with necessary changes.

## Thoughts about switch to Cloud Run
### 1. Simplify the infrastruture
Fully managed service and focus on application instead of underneath infrastructure. 

### 2. Enhanced observerbility
Distributed tracing is enabled by default.

### 3. Built-in security
Support https and IAM authentication by default.

### 4. Better scalability
Rapid scaling.


## What to change

1. Take out enssential content from YAML to create serving service.
2. Configure parameters for each individual services.
3. Configure service to service call with proper authentication. 
4. Expose the public service through GLB.



## Deploy into Managed Cloud Run

```bash

# 1. Prerequisite
gcloud services enable 
gcloud iam service-accounts

# 2. Setup Botique on Cloud Run
git clone git@github.com:cc4i/boutique-on-cloudrun.git
cd boutique-on-cloudrun

gcloud builds submit --config=cloudbuild.yaml --async

```

## Deploy into Cloud Run on GKE

```bash

export PROJECT_ID=play-with-anthos-340801
export CLUSTER=cloudrun-gke
export ZONE=asia-east2-b

# Provision GKE
gcloud container --project ${PROJECT_ID} clusters create ${CLUSTER} \
    --machine-type "n2d-standard-4" \
    --scopes "https://www.googleapis.com/auth/cloud-platform" \
    --num-nodes "3" \
    --workload-pool "${PROJECT_ID}.svc.id.goog" \
    --zone ${ZONE}


# Register into Fleet
# gcloud container fleet memberships register ${CLUSTER} \
#  --gke-cluster=${ZONE}/${CLUSTER} \
#  --enable-workload-identity

# Run following commands in CloudShell
mkdir bin;cd bin
curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_1.13 > asmcli
chmod +x asmcli
./asmcli install \
  --project_id ${PROJECT_ID} \
  --cluster_name ${CLUSTER} \
  --cluster_location ${ZONE} \
  --fleet_id ${PROJECT_ID} \
  --output_dir ~/bin \
  --enable_all \
  --ca mesh_ca
# 

# Apply Cloud Run to GKE
# gcloud config set run/platform gke
# gcloud config set run/cluster_location ${ZONE}
gcloud container fleet cloudrun apply --gke-cluster=${ZONE}/${CLUSTER}


```


## Expand to multi-region deployment

## Notes
1. Be careful some of features are not support in managed Cloud Run, but have support in Knative. Reason for that is to reduce cold start.

Not supported:
```
    - readinessProbe
    - livenessProbe
```


2. cpu < 1 is not supported with concurrency > 1

3. Not support to inject evironments, such as "PORT" (due to conflict with system auto-injection)

4. Services access other services on Cloud Run must be authorized, which has to provide identity token.

5. Refactor how gRPC call other services with authorization - https://cloud.google.com/run/docs/triggering/grpc

6. To get the dns of Cloud Run service, must deploy first. In some cases your services depends on other services, you must deploy dependent services and then retrieve the dns of the service, and then update related parameters before deployment. 

7. Be careful with identity toke, by default the token will be expired after 60 minutes, so we should find a proper mechanism to manage those indentity token, processing them in application should be straight forward. Or alternatively store them into redis and process accordingly. 



