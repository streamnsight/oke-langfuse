# Cluster Autoscaler Add-On, multi-deployment wrapper module

The cluster autoscaler add-on, when deployed on OKE, allows horizontal scaling of node pools based on resource requirements.

This module is a wrapper module which determines the best way to deploy the add-on based on the cluster type.

If you know which way you want to deploy, you may use the module of your choice directly. The `deployment` subfolder contains sub-modules to select from.


## How to use

The module is split up into sub-components that are selected depending on the deployment strategy. With enhanced clusters, the cluster autoscaler add-on can be deploy as a managed resource. For basic clusters, users need to deploy the add-on themselves.
Public endpoint OKE clusters make it easy to deploy charts or manifests directly, but are less secure. With private endpoint clusters, however, deployment using Terraform is made difficult because of the lack of tunneling capability; in that case, an OCI DevOps pipeline can be used.

The cluster autoscaler also support multiple authorization schemes. This module supports both the use of a Dynamic Group, or the more secure use of Workload Identity.

