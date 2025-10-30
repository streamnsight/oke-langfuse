# metrics-server, multi-deployment wrapper module

This module wraps deployment of `metrics-server`, choosing the proper deployment method depending on the cluster type.

If you know what metod you want to use to deploy the metrics server, you can use the specific module in the `deployment` folder.

Note: `metrics-server` is deployed by default with `cluster-autoscaler` add-on for enhanced OKE clusters, therefore it is currently not an option to deploy it separately. If you are deploying `cluster-autoscaler`, you do not need to deploy `metrics-server`, however if you need `metrics-server` in an enhanced cluster but don't deploy `cluster-autoscaler`, you need to deploy it yourself, using either the pubklic endpoint or private endpoint deployment method.

# How to use

