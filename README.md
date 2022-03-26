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