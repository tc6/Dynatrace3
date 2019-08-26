# Dynatrace PaaS Agent @ Docker Image
You can either choose to instrument your docker image at build or runtime. The advantages/disadvantages are mentioned in the next paragraph 
## build time vs run time
We can either package the PaaS Agent during build time or during run time.   

<table style="width:100%">
  <tr>
    <th>Topic</th>
    <th>Buildtime</th> 
    <th>Runtime</th>
  </tr>
  <tr>
    <td>Minimal startup time</td>
    <td>&#9989;</td> 
    <td>&#10060;</td>
  </tr>
  <tr>
    <td>Fail safe startup even when the cluster is not available</td>
    <td>&#9989;</td> 
    <td>&#10060;</td>
  </tr>
  <tr>
    <td>Always compatible with the cluster</td>
    <td>&#10060;</td> 
    <td>&#9989;</td>
  </tr>
  <tr>
    <td>Simple</td>
    <td>&#10060;</td> 
    <td>&#9989;</td>
  </tr>
  <tr>
    <td>Works if you do not build your images regulary</td>
    <td>&#10060;</td> 
    <td>&#9989;</td>
  </tr>
  <tr>
    <td>No secrets in your artifactory</td>
    <td>&#9989; with some effort</td> 
    <td>&#9989;</td>
  </tr>
</table>

### Run Time
The PaaS Agent will be downloaded and installed within your Docker container when the container is started. A script must be provided as an entrypoint, which will download the agent, install it and finally start your application. 

You can use our [agent.sh script](./scripts/agent.sh) in order to see the required steps. `./agent.sh start` will download the agent from a cluster and instrument the container. The parameter for the agent download are either provided via environment variables (DT_API_URL, DT_API_TOKEN, DT_TENANT) or, optionally, via a user-provided service on Cloud Foundry. 

### Build Time
With this approach, the PaaS agent is added to the image so that it is already available within the container during creation. Our example makes use of a base image which has the PaaS agent downloaded and properly installed. Due to security reasons, the environment id and the PaaS token are removed from the base image. Make sure to provide `DT_API_TOKEN`, `DT_API_URL` and `DT_TENANT` via environment variables.

Please note:
 * The script downloads the PaaS agent from the cluster you provide via `DT_API_URL` variable. The PaaS agent must not be newer than the cluster it reports metrics to.
 * Dynatrace clusters are regularly upgraded. Live clusters are always upgraded last (i.e. after Canary) - we recommend to use a live cluster for preparation so that the PaaS agent is not newer than your cluster.
 
#### Dockerfile
You have to execute `./agent.sh prepare`, this will download and install the agent from a cluster. The parameter for the agent download are provided via environment variables (`DT_API_URL, DT_API_TOKEN, DT_TENANT`). All links to the cluster will be removed from the image, so you can check it into your artifactory.

#### Container start
You have to add communication details to the prepared agent. This can be done via `./agent.sh start`. The parameters for the agent download are either provided via environment variables (`DT_API_URL, DT_API_TOKEN, DT_TENANT`) or using a user-provided service if the container is started on Cloud Foundry.  


## Detailed information
The PaaS Agent is available at `https://[CLUSTER]/e/[ENVIRONMENT-ID]/api/v1/deployment/installer/agent/unix/paas-sh/latest?flavor=[FLAVOR]&include=[TECHNOLOGY]&Api-Token=[TOKEN]&bitness=64&arch=x86`. Please replace `[CLUSTER]` by the cluster URL, e.g. `apm.cf.eu10.hana.ondemand.com`, and insert the environment ID and a PaaS-Token. 

For non-Alpine images, please set `[FLAVOR]` to `default`, otherwise set it to `musl`. Furthermore, `[TECHNOLOGY]` can be one of `all`, `java`, `apache`, `nginx`, `nodejs`, `dotnet` and `php` for non-Alpine images; For Alpine images, only `all`, `java`, `apache`, `nginx` and `nodejs`are available.

During installation, the PaaS Agent agent will make use of the `export LD_PRELOAD=/opt/dynatrace/oneagent/agent/lib64/liboneagentproc.so` so that your processes get instrumented.

