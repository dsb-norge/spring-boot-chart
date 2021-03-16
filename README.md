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


## Define a CronJob

Define a `jobs` entry like below:

    jobs:
    - name: oauth-cron-example
      image_tag: 2abff46
      schedule: "*/1 * * * *"
      tokenURL: "https://devinternlogin.dsb.no/auth/realms/AD/protocol/openid-connect/token"
      apiPath: "/ping"
      method: "GET"

Required parameters:
* `name` - A name used to identify the given cron
* `image_tag` - the version of [k8s-cron-api-caller](https://github.com/dsb-norge/k8s-cron-api-caller) to use
* `schedule` - A given schedule to run on
* `tokenURL` - Path to get an oauth access token with `client_credentials` flow
* `apiPath` - The path to an endpoint on the current service/application to run

Optional parameters:
* `method` - The HTTP method to run GET/POST/PUT... Not specifying will make it a POST
* `clientId` - The clientID to use for access token. Default is: `<RELEASE_NAME>-cron-client`


You also require a client secret which is defined like the regular values.secrets only its from `values.job_secrets`
it needs to define a value called: `CLIENT_SECRET`