#!/bin/bash
set -euxo pipefail

# Pull needed images:
docker pull quintush/helm-unittest
docker pull quay.io/helmpack/chart-testing:latest

# Run Helm linting:
docker run -it --rm --name ct --volume "$( pwd )":/data quay.io/helmpack/chart-testing:latest sh -c "ct lint --all --debug --chart-dirs data/"

# Run unit tests:
docker run -it --rm --name unittest --volume "$(pwd)":/apps quintush/helm-unittest --helm3 charts/*
# Update snapshots:
# docker run -it --rm --name unittest --volume "$(pwd)":/apps quintush/helm-unittest --helm3 --update-snapshot charts/*

# Create Kubernetes cluster:
kind create cluster --config kind-cluster-config.yaml

# Fetch test application used to test the charts:
az acr login -n dsbacr
docker pull dsbacr.azurecr.io/dsb-norge/test-application:2021.06.03.69273
kind load docker-image dsbacr.azurecr.io/dsb-norge/test-application:2021.06.03.69273

# Run Helm tests:
docker run -it --rm --name ct --volume "$( pwd )":/data quay.io/helmpack/chart-testing:latest sh -c "ct install --all --debug --chart-dirs data/"

# Delete Kubernetes cluster:
kind delete cluster
