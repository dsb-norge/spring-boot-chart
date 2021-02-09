## Helm 3 chart for Spring Boot Applications

Release the chart by invoking the workflow 'Release the chart' in Github, and then specify the desired version:

https://github.com/dsb-norge/spring-boot-chart/actions?query=workflow%3A%22Release+the+chart%22

To debug locally (requires a kubeconfig setup to a live cluster):

    helm upgrade --install --debug --dry-run --atomic -f example.yaml test-application dsb-spring-boot
    
The file `example.yaml` could be like this:

    ---
    replicas: 2
    
    image: "ghcr.io/dsb-norge/test-application"
    tag: "latest"
    
    application_traefik_rule: "Host(`dev-api.eksplosiver.no`) && PathPrefix(`/test`)" 
