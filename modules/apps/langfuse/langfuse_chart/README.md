# Langfuse Chart Module

This module manages the deployment and configuration of the Langfuse application using the Langfuse Helm chart. 
It provisions the necessary Kubernetes resources and integrates with OCI DevOps for deployment of the Langfuse chart.
Some of the steps (image build and secrets creation) are performed in a compute instance builder VM as DevOps requires PAT tokens to access public github repos which makes the 1-click deployment process more complex for the end user.


