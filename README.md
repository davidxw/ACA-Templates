# Bicep Templates for Azure Container Apps


![Overview diagram](./docs/overview.png)


## Infra

Infrastructure deployed to host Azure Container Apps. Deploy only if you don't already have a container apps environment (reference to Landing Zone Accelerator):

* Log Analytics Workspace
* Azure Key Vault using the Azure RBAC permissions model. You will have to make yourself a Secrets adminstrator if you would like view and update secrets 
* Azure Container Registry
* Azure Container App Environment - deployed into a VNet in internal mode
* An identity for the Azure Container App Environment
* Private DNS Zone for default ACA environment domain, and optionally for custom domain
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

After the infra has been deployed you can deploy the your container app services. Before you deploy you will need to copy the required container app images to the Azure Container Registry, e.g.

```bash
az acr import  --name dssContainerRegistry --source docker.io/davidxw/webtest:latest  --image davidxw/webtest:latest
```
When the container images are in the Azure Container Registry you can deploy your app.

* Change to the `templates\apps`  directory 
* Create a copy of the `sample_apps.bicepparam` file and update the parameters accordingly. Which the exception of the service paramater objects the other values should be the same as those you used for the infra deployment.
* Run the following command to deploy the infrastructure:

```bash
az deployment group create --resource-group containerAppResourceGroup --parameters ./your_apps.bicepparam
```

### Service Params Object

The app deployment template contains a `service_params` object that is used to configure the Container Apps. The object is a list of service configuration objects, one for each service. The format of the object is:

```bicep
  {
    name: 'aca-service'
    container_name: 'webtest'
    container_image: 'davidxw/webtest:latest'
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

* `envs`, `envs_secret`, and `volume_mounts` are optional
* The deployment creates an Azure Files Share for each service, and mounts all the specified volume mounts for a service to that share. `subPath` is optional, and if not specified the volume mount will be mounted to the root of the share.
* All items in `envs_secret` are stored in the Azure Key Vault, with the env name as the secret name. A container app secret is create for each (referencing the Key Vault secret), and the container app environment variable references the Container App secret.