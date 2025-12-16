# Langfuse Load Balancer (TLS) Module

This module provisions a load balancer for the Langfuse application with TLS encryption. It creates the necessary networking and load balancing resources for secure HTTPS access.

The Certificate is created using cert-manager and LetsEncrypt to create a IP-based cert.

IP-certs are very new and only LetsEncrypt provides those. They require the short-lived profile which is only available in staging as of Dec 2025, but will be available for prod soon. The cert is not technically valid in the mean-time.

TODO: switch to pdo provider when short-lived profile and IP-certs are available in prod.

