# recommended-compute-image

This module takes a compute image OCID and a Kubernetes version and finds the OKE-optimized equivalent image OCID. 

The OKE-specific image for a given OS / architecture / Kubernetes version combination is an image based on the requested compute image, with all of the kubernetes dependencies pre-installed. This results in faster node boot times and therefore shorter response times when scaling node pools.

Note: Not all base images have an OKE-optimized equivalent. When none exists, the provided image OCID will be used as-is.
