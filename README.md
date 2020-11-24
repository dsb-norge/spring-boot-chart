## Helm 3 chart for Spring Boot Applications

To debug locally (requires a kubeconfig setup to a live cluster):

    helm upgrade --install --debug --dry-run --atomic -f example.yaml test-application dsb-spring-boot
    
The file `example.yaml` could be like this:

    ---
    replicas: 2
    
    image: "ghcr.io/dsb-norge/test-application"
    tag: "latest"
    
    application_traefik_rule: "Host(`dev-api.eksplosiver.no`) && PathPrefix(`/test`)" 