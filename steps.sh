# set parameter variables
PREFIX="shademo"
RESOURCE_GROUP="$PREFIX-RG"
LOCATION="northeurope"
CONTAINERAPPS_ENVIRONMENT="$PREFIX-app-env"
LOG_ANALYTICS_WORKSPACE="$PREFIX-la"
COSMOSDB_ACCOUNT_NAME="$PREFIX-cosmosdb"
COSMOSDB_DB_NAME="$PREFIX-cosmosdb"
COSMOSDB_COLLECTION_NAME="order"
ACR_NAME=$PREFIX"reg"
ACR_URL="$ACR_NAME.azurecr.io"

# set up azure cli and login
az login --use-device-code
az upgrade
az extension add \
  --source https://workerappscliextension.blob.core.windows.net/azure-cli-extension/containerapp-0.2.0-py2.py3-none-any.whl
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

COSMOSDB_ENDPOINT=`az cosmosdb show -n $COSMOSDB_ACCOUNT_NAME  -g $RESOURCE_GROUP --query documentEndpoint --out tsv`
COSMOSDB_MASTER_KEY=`az cosmosdb keys list -n $COSMOSDB_ACCOUNT_NAME  -g $RESOURCE_GROUP --query primaryMasterKey --out tsv`

sed -i "s|<URL>|$COSMOSDB_ENDPOINT|" components.yaml
sed -i "s|<KEY>|$COSMOSDB_MASTER_KEY|" components.yaml
sed -i "s|<DB>|$COSMOSDB_DB_NAME|" components.yaml

az acr create \
    --name $ACR_NAME \
    --resource-group $RESOURCE_GROUP \
    --sku Standard \
    --location $LOCATION \
    --admin-enabled

ACR_PASSWORD=`az acr credential show -n $ACR_NAME --query passwords[0].value  --out tsv`

# build and push container images 
az acr build -t pythonapp:latest -r $ACR_NAME ./src/python
az acr build -t nodeapp:latest -r $ACR_NAME ./src/node

# create container apps env
az containerapp env create \
    --name $CONTAINERAPPS_ENVIRONMENT \
    --resource-group $RESOURCE_GROUP \
    --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_CLIENT_ID \
    --logs-workspace-key $LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET \
    --location $LOCATION

IMAGE_NAME=$ACR_URL"/nodeapp:latest"

az containerapp create \
    --name nodeapp \
    --resource-group $RESOURCE_GROUP \
    --environment $CONTAINERAPPS_ENVIRONMENT \
    --image $IMAGE_NAME \
    --target-port 3000 \
    --ingress 'external' \
    --min-replicas 1 \
    --max-replicas 1 \
    --enable-dapr \
    --dapr-app-port 3000 \
    --dapr-app-id nodeapp \
    --dapr-components ./components.yaml \
    --registry-login-server $ACR_URL \
    --registry-username $ACR_NAME \
    --registry-password $ACR_PASSWORD

IMAGE_NAME=$ACR_URL"/pythonapp:latest"

az containerapp create \
    --name pythonapp \
    --resource-group $RESOURCE_GROUP \
    --environment $CONTAINERAPPS_ENVIRONMENT \
    --image $IMAGE_NAME \
    --min-replicas 1 \
    --max-replicas 1 \
    --enable-dapr \
    --dapr-app-id pythonapp \
    --registry-login-server $ACR_URL \
    --registry-username $ACR_NAME \
    --registry-password $ACR_PASSWORD

az monitor log-analytics query \
  --workspace $LOG_ANALYTICS_WORKSPACE_CLIENT_ID \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s == 'nodeapp' and (Log_s contains 'persisted' or Log_s contains 'order') | project ContainerAppName_s, Log_s, TimeGenerated | take 5" \
  --out table

