# Langfuse Load Balancer (No TLS) Module

This module provisions a load balancer for the Langfuse application without TLS encryption. It sets up the necessary networking and load balancing resources for HTTP-only access.

The Langfuse LB is deployed with no TLS first to get an IP address. The TLS version is then implemented as the IP is needed to create the IP based TLS certificate.