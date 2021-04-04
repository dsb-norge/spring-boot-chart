docker pull quay.io/helmpack/chart-testing:latest
docker run -it --rm --name ct --volume %cd%:/data quay.io/helmpack/chart-testing:latest sh -c "ct lint --all --debug --chart-dirs /data/"

kind create cluster --config kind-cluster-config.yaml
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
helm install traefik traefik/traefik

az acr login -n dsbacr
docker pull dsbacr.azurecr.io/dsb-norge/test-application:2021.03.16.46359
kind load docker-image dsbacr.azurecr.io/dsb-norge/test-application:2021.03.16.46359

docker run -it --rm --name ct --volume %cd%:/data quay.io/helmpack/chart-testing:latest sh -c "ct install --all --debug --chart-dirs /data/"

kind delete cluster
