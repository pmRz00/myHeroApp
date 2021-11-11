# set parameter variables
RESOURCE_GROUP="HeroAppSample"
NAME="hero"
LOCATION="canadacentral"
CONTAINERAPPS_ENVIRONMENT="HeroApp-env"
LOG_ANALYTICS_WORKSPACE="HeroApp-logs"
COSMOSDB_ACCOUNT_NAME="heroapp-cosmosdb"
COSMOSDB_DB_NAME="HeroApp-cosmosdb"
COSMOSDB_COLLECTION_NAME="order"

# set up azure cli and login
az login --use-device-code
az upgrade
az provider register --namespace Microsoft.Web

# create rg
az group create --name $RESOURCE_GROUP --location $LOCATION

# set up az monitor and log analytics workspace
az monitor log-analytics workspace create \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $LOG_ANALYTICS_WORKSPACE

LOG_ANALYTICS_WORKSPACE_CLIENT_ID=`az monitor log-analytics workspace show --query customerId -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE --out tsv`
LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET=`az monitor log-analytics workspace get-shared-keys --query primarySharedKey -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE --out tsv`

az cosmosdb create \
    --name $COSMOSDB_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP 

az cosmosdb database create \
    --name $COSMOSDB_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --db-name $COSMOSDB_DB_NAME

az cosmosdb collection create \
    --collection-name $COSMOSDB_COLLECTION_NAME \
    --db-name $COSMOSDB_DB_NAME \
    --name $COSMOSDB_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --partition-key-path /partitionKey

# create container apps env
az containerapp env create \
    --name $CONTAINERAPPS_ENVIRONMENT \
    --resource-group $RESOURCE_GROUP \
    --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_CLIENT_ID \
    --logs-workspace-key $LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET \
    --location $LOCATION

az containerapp create \
    --name nodeapp \
    --resource-group $RESOURCE_GROUP \
    --environment $CONTAINERAPPS_ENVIRONMENT \
    --image dapriosamples/hello-k8s-node:latest \
    --target-port 3000 \
    --ingress 'external' \
    --min-replicas 1 \
    --max-replicas 1 \
    --enable-dapr \
    --dapr-app-port 3000 \
    --dapr-app-id nodeapp \
    --dapr-components ./components.yaml

az containerapp create \
    --name pythonapp \
    --resource-group $RESOURCE_GROUP \
    --environment $CONTAINERAPPS_ENVIRONMENT \
    --image dapriosamples/hello-k8s-python:latest \
    --min-replicas 1 \
    --max-replicas 1 \
    --enable-dapr \
    --dapr-app-id pythonapp

az monitor log-analytics query \
  --workspace $LOG_ANALYTICS_WORKSPACE_CLIENT_ID \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s == 'nodeapp' and (Log_s contains 'persisted' or Log_s contains 'order') | project ContainerAppName_s, Log_s, TimeGenerated | take 5" \
  --out table
