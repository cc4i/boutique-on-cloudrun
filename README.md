# Boutique on Cloud Run

## Thoughts about switch to Cloud Run

## What to change

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