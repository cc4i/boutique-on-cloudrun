# Boutique on Cloud Run

## Notice
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