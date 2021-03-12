## Helm 3 chart for Spring Boot Applications

Create a new release by creating a tag prefixed with 'v' (like v1.0.0):

https://github.com/dsb-norge/spring-boot-chart/releases/new

Note that the release will be without the prefix 'v'.

To debug locally (requires a kubeconfig setup to a live cluster):

    helm upgrade --install --debug --dry-run -f example.yaml test-application dsb-spring-boot
    
The file `example.yaml` could be like this:

    ---
    replicas: 2
    
    image: "dsbacr.azurecr.io/dsb-norge/test-application"
    tag: "latest"
    
    application_traefik_rule: "Host(`dev-api.eksplosiver.no`) && PathPrefix(`/test`)" 

To actually deploy, omit the --dry-run flag.
