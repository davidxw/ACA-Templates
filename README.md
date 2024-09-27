# Bicep Templates for Azure Container Apps

![Overview diagram](./docs/overview.png)

## Infra

Infrastructure deployed to host Azure Container Apps. Deploy only if you don't already have an existing container apps environment (e.g. the [Azure Container Apps Landing Zone Accelerator](https://github.com/Azure/aca-landing-zone-accelerator)):

* Log Analytics Workspace
* Azure Key Vault using the Azure RBAC permissions model. You will have to make yourself a Secrets adminstrator if you would like view and update secrets 
* Azure Container Registry
* Azure Container App Environment
* Private DNS Zone for default ACA environment domain if the environment is deployed in internal mode, and optionally for custom domain
* Role assignments for the Azure Container App Environment identity to the Azure Container Registry and the Azure Key Vault

To deploy the infrastructure:

* Create a resource group:

```bash
az group create --name containerAppResourceGroup --location australiaeast
```
* Change to the `templates\infra`  directory 
* Create a copy of the `sample_params.bicepparam` file and update the parameters accordingly.
* Run the following command to deploy the infrastructure:

```bash
az deployment group create --resource-group containerAppResourceGroup --parameters ./your_params.bicepparam
```

## Apps

After the infra has been deployed you can deploy the your container app services.  The templates can handle either container images from docker.io, or from an Azure Container Registry.  If you would like to copy public images into your ACR you ca use the command below:

```bash
az acr import  --name dssContainerRegistry --source docker.io/davidxw/webtest:latest  --image davidxw/webtest:latest
```
To deploy your apps:

* Change to the `templates\apps`  directory 
* Create a copy of the `sample_apps.bicepparam` file and update the parameters accordingly. The only required parameters are the `aca_env_name` and `service_params` object (more on thie below). You may also need to specify the following parameters, depending on your requirements:
  * `container_registry_name` - if your images are in an ACR
  * `key_vault_name` - if you secret environment variables that need to be stored in a Key Vault
  * `files_storage_account_name` - if you have volumn mounts that need to be stored in an Azure Files Share
* Run the following command to deploy the infrastructure:

```bash
az deployment group create --resource-group containerAppResourceGroup --parameters ./your_apps.bicepparam
```

### Service Params Object

The app deployment template contains a `service_params` object that is used to configure the Container Apps. The object is a list of service configuration objects, one for each service. The format of the object is:

```bicep
  {
    name: 'aca-service-1'
    ingress_external: true
    target_port: 80
    workload_profile: 'Consumption'
    container_name: 'webtest'
    container_image: 'containerRegistry.azurecr.io/davidxw/webtest:latest'
    envs: {
      SQL_SERVER: 'sql_server'
      SQL_DATABASE: 'sql_database'
      SQL_USER: 'sql_user'
    }
    envs_secret: {
      SQL_PASSWORD: 'secret string'
    }
    volume_mounts: [
    {
       mountPath: '/app/logs'
       subPath: 'logs'
     }
    ]
  }
```

Notes:

* The only required propperties are `name` and `container_image`.
* The template currently assumes that all containers have ingress enabled, use `is_ingress_external` to specify if the service should be exposed externally. If `is_ingress_external`not specified, the service will be exposed externally.
* If `target_port` is not specified, the service will expect the container to listen on port 80.
* If `workload_profile` is not specified, the service will use the Consumption plan.
* If `container_name` is not specified, the service will use the service name as the container name.
* If you container images is stored in ACR, you must included the registry name in the `container_image` parameter (e.g. `containerRegistry.azurecr.io/davidxw/webtest:latest`).
* `envs`, `envs_secret`, and `volume_mounts` are optional. If `envs_secret` is specified, then a `key_vault_name` parameter must also be specified. If `volume_mounts` is specified, then a `files_storage_account_name` parameter must also be specified. If you are using a public image then only the path and tag are required (e.g. `davidxw/webtest:latest`).
* The deployment creates an Azure Files Share for each service, and mounts all the specified volume mounts for a service to that share. `subPath` is optional, and if not specified the volume mount will be mounted to the root of the share.
* All items in `envs_secret` are stored in the Azure Key Vault, with the env name as the secret name. A container app secret is create for each (referencing the Key Vault secret), and the container app environment variable references the Container App secret.
* Currently only one container per service is supported.