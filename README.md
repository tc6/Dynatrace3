# Dynatrace related Docker scripts

This repository contains:
- Docker base images instrumented by the Dynatrace PaaS agent based on cflinuxfs3 with detailed information about their usage, and
- Dynatrace Environment ActiveGate Docker images based on cflinuxfs3, ready-to-use as a Kubernetes Helm Chart or Cloud Foundry Docker based application.

## PaaS Agent 

A docker-compose file is provided within [images/paasagent](./images/paasagent), which creates two Docker images. 
- `java_buildtime` is a sample base image with a pre-downloaded and installed PaaS agent, resulting in a low startup time of the container. 
- `java_runtime` is a sample base image which requires the download and installation of the PaaS agent during container start. 

More detailed information, advantages and disdvantages of both images are available in the [README.md](./images/paasagent/README.md)

## Environment ActiveGates
Environment ActiveGates can help by reducing the load on Dynatrace in case of high activity within your environment (e.g. extensive usage of AWS cloud watch). Moreover, environment ActiveGates enable synthetic monitoring which can be used to execute sophisticated health checks on UIs.

Environment ActiveGate Docker images for CloudFoundry or Kubernetes can be built via [docker-compose](./images/environment-activegate/docker).<!-- or used directly from the DMZ artifactory. --> 

### Cloud Foundry

Deploy the Environment ActiveGate as a Docker based application on Cloud Foundry via the provided [manifest.yml](./images/environment-activegate/manifest.yaml).

### Kubernetes

Use the provided [Helm Chart](./images/environment-activegate/helm) to deploy the Environment ActiveGate on Kubernetes.
