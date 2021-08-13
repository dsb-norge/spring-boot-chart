#!/bin/bash
set -euxo pipefail

az acr login -n dsbacr

docker pull quay.io/helmpack/chart-testing:latest
docker run -it --rm --name ct --volume "$( pwd )":/data quay.io/helmpack/chart-testing:latest sh -c "ct lint --all --debug --chart-dirs data/"

kind create cluster --config kind-cluster-config.yaml

docker pull dsbacr.azurecr.io/dsb-norge/test-application:2021.06.03.69273
kind load docker-image dsbacr.azurecr.io/dsb-norge/test-application:2021.06.03.69273

docker run -it --rm --name ct --volume "$( pwd )":/data quay.io/helmpack/chart-testing:latest sh -c "ct install --all --debug --chart-dirs data/"

kind delete cluster
