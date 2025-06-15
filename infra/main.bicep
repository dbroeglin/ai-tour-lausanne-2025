metadata name = 'az-ai-kickstarter'
metadata description = 'Deploys the infrastructure for Azure AI App Kickstarter'
metadata author = 'AI GBB EMEA <eminkevich@microsoft.com>; <dobroegl@microsoft.com>'

/* -------------------------------------------------------------------------- */
/*                                 PARAMETERS                                 */
/* -------------------------------------------------------------------------- */

@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@description('Principal ID of the user running the deployment')
param azurePrincipalId string

@description('Location for all resources')
param location string

@description('Extra tags to be applied to provisioned resources')
param extraTags object = {}

@description('If true, deploy Azure AI Search Service')
param useAiSearch bool = false

@description('If true, use and setup authentication with Azure Entra ID')
param useAuthentication bool = false

@description('Set to true to use an existing AI Foundry service.In that case you will need to provide aiFoundryEndpoint, aiFoundryApiVersion, executorAiFoundryDeploymentName and utilityAiFoundryDeploymentName. Defaults to false.')
param useExistingAiFoundry bool = false

@description('Set to true to use an existing Azure AI Search service.In that case you will need to provide TODO. Defaults to false.')
param useExistingAiSearch bool = false

/* -----------------------  Azure Open AI  service ------------------------- */

// See also https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models?tabs=global-standard%2Cstandard-chat-completions#availability-1
@description('Location for the AI Foundry resource')
@metadata({
  azd: {
    type: 'location'
  }
})
param aiFoundryLocation string = ''

/* -------- Optional externally provided AI Foundry configuration -------- */

@description('Optional. The name of the AI Foundry resource to reuse. Used only if useExistingAiFoundry is true.')
param aiFoundryName string = ''

@description('Optional. The endpoint of the AI Foundry resource to reuse. Used only if useExistingAiFoundry is true.')
param aiFoundryEndpoint string = ''

@description('Optional. The API version of the AI Foundry resource to reuse. Used only if useExistingAiFoundry is true.')
param aiFoundryApiVersion string = ''

@description('Optional. The name of the AI Foundry deployment for the executor to reuse. Used only if useExistingAiFoundry is true.')
param executorAiFoundryDeploymentName string = ''

@description('Optional. The name of the AI Foundry deployment for the utility to reuse. Used only if useExistingAiFoundry is true.')
param utilityAiFoundryDeploymentName string = ''

@description('The AI Foundry service resource group name to reuse. Optional: Needed only if resource group is different from current resource group.')
param aiFoundryResourceGroupName string = ''

/* -----------------------  Azure AI search service ------------------------ */

@description('Optional. Defines the SKU of an Azure AI Search Service, which determines price tier and capacity limits.')
@allowed([
  'basic'
  'free'
  'standard'
  'standard2'
  'standard3'
  'storage_optimized_l1'
  'storage_optimized_l2'
])
param aiSearchSkuName string = 'basic'

// See https://learn.microsoft.com/en-us/azure/search/search-region-support
@description('Location for the Azure OpenAI Service. Optional: needed only if Azure OpenAI is deployed in a different location than the rest of the resources.')
@metadata({
  azd: {
    type: 'location'
  }
})
param azureAiSearchLocation string = ''

@description('Name of the Azure AI Search Service to deploy. Optional: needed if useExistingAiSearchService is true or you want a custom azureAiSearchName.')
param azureAiSearchName string = ''

@description('The Azure AI Search service resource group name to reuse. Optional: Needed only if resource group is different from current resource group.')
param azureAiSearchResourceGroupName string = ''

/* ---------------------------- Shared Resources ---------------------------- */

@maxLength(63)
@description('Name of the log analytics workspace to deploy. If not specified, a name will be generated. The maximum length is 63 characters.')
param logAnalyticsWorkspaceName string = ''

@maxLength(255)
@description('Name of the application insights to deploy. If not specified, a name will be generated. The maximum length is 255 characters.')
param applicationInsightsName string = ''

@description('Application Insights Location')
param appInsightsLocation string = location

@description('The auth tenant id for the app (leave blank in AZD to use your current tenant)')
param authTenantId string = '' // Make sure authTenantId is set if not using AZD

@description('Name of the authentication client secret in the key vault')
param authClientSecretName string = 'AZURE-AUTH-CLIENT-SECRET'

@description('The auth client id for the frontend and backend app')
param authClientAppId string = ''

@description('Client secret of the authentication client')
@secure()
param authClientSecret string = ''

@maxLength(50)
@description('Name of the container registry to deploy. If not specified, a name will be generated. The name is global and must be unique within Azure. The maximum length is 50 characters.')
param containerRegistryName string = ''

/* -------------------------------------------------------------------------- */
/*                                  VARIABLES                                 */
/* -------------------------------------------------------------------------- */

// Load abbreviations from JSON file
var abbreviations = loadJsonContent('./abbreviations.json')

@description('Generate a unique token to make global resource names unique')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

@description('Name of the environment with only alphanumeric characters. Used for resource names that require alphanumeric characters only')
var alphaNumericEnvironmentName = replace(replace(environmentName, '-', ''), ' ', '')

@description('Tags to be applied to all provisioned resources')
var tags = union(
  {
    'azd-env-name': environmentName
    solution: 'az-ai-kickstarter'
  },
  extraTags
)

/* --------------------- Globally Unique Resource Names --------------------- */

var _applicationInsightsName = !empty(applicationInsightsName)
  ? applicationInsightsName
  : take('${abbreviations.insightsComponents}${environmentName}', 255)
var _logAnalyticsWorkspaceName = !empty(logAnalyticsWorkspaceName)
  ? logAnalyticsWorkspaceName
  : take('${abbreviations.operationalInsightsWorkspaces}${environmentName}', 63)

var _storageAccountName = take(
  '${abbreviations.storageStorageAccounts}${alphaNumericEnvironmentName}${resourceToken}',
  24
)
var _aiFoundryName = useExistingAiFoundry
  ? aiFoundryName // if reusing existing service, use the provided name
  : (empty(aiFoundryName) // else use only if not empty to override the default name
      ? take('${abbreviations.cognitiveServicesOpenAI}${alphaNumericEnvironmentName}${resourceToken}', 63)
      : aiFoundryName)

var _aiProjectName = take('${abbreviations.aiPortalProject}${environmentName}', 260)

var _azureAiSearchName = useExistingAiSearch
  ? azureAiSearchName // if reusing existing service, use the provided name
  : (empty(azureAiSearchName) // else use only if not empty to override the default name
      ? take('${abbreviations.searchSearchServices}${environmentName}', 260)
      : azureAiSearchName)

var _containerRegistryName = !empty(containerRegistryName)
  ? containerRegistryName
  : take('${abbreviations.containerRegistryRegistries}${alphaNumericEnvironmentName}${resourceToken}', 50)
var _keyVaultName = take('${abbreviations.keyVaultVaults}${alphaNumericEnvironmentName}-${resourceToken}', 24)

/* ----------------------------- Resource Names ----------------------------- */

// These resources only require uniqueness within resource group

@description('Model deployment configurations')
var deployments = loadYamlContent('./deployments.yaml')


var _aiFoundryEndpoint = useExistingAiFoundry ? aiFoundryEndpoint : aiServices.outputs.endpoint

@description('AI Foundry API Version')
var _aiFoundryApiVersion = empty(aiFoundryApiVersion) ? '2025-05-01-preview' : aiFoundryApiVersion

@description('Azure AI Foundry Model Deployment Name - Executor Service')
var _executorAiFoundryDeploymentName = !empty(executorAiFoundryDeploymentName)
  ? executorAiFoundryDeploymentName
  : deployments[0].name

@description('Azure AI Foundry Model Deployment Name - Utility Service')
var _utilityAiFoundryDeploymentName = !empty(utilityAiFoundryDeploymentName)
  ? utilityAiFoundryDeploymentName
  : deployments[1].name

var _projectConnectionString = 'https://${_aiFoundryName}.services.ai.azure.com/api/projects/${aiProject.outputs.name}'

var _azureAiSearchLocation = empty(azureAiSearchLocation) ? location : azureAiSearchLocation
var _azureAiSearchEndpoint = 'https://${_azureAiSearchName}.search.windows.net'

/* -------------------------------------------------------------------------- */
/*                                  RESOURCES                                 */
/* -------------------------------------------------------------------------- */

module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = {
  name: '${deployment().name}-containerRegistry'
  params: {
    name: _containerRegistryName
    location: location
    tags: tags
    acrSku: 'Standard'
    acrAdminUserEnabled: true
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'AcrPull'
        principalId: azurePrincipalId
      }
    ]
  }
}

module keyVault 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: '${deployment().name}-keyVault'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    name: _keyVaultName
    enableRbacAuthorization: true
    enablePurgeProtection: false // Set to true to if you deploy in production and want to protect against accidental deletion
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Key Vault Administrator'
        principalId: azurePrincipalId
      }
    ]
    secrets: useAuthentication && authClientSecret != ''
      ? [
          {
            name: authClientSecretName
            value: authClientSecret
          }
        ]
      : []
  }
}

//------------------------------ AI Foundry  ------------------------------ */

// PROVISIONARY SOLUTION.
// The module is being updated to support the latest Azure AI Foundry features.
// Meanwhile created a local copy of 0.10.2 including "allowProjectManagement: true"
// Also it requires managedIdentites to be set.
// Once the official module is updated, we will switch back to it.
module aiServices 'modules/ai/account.bicep' = if (!useExistingAiFoundry) {
// module aiServices 'br/public:avm/res/cognitive-services/account:0.10.2' = if (!useExistingAiFoundry) {
  name: '${deployment().name}-aiServices'
  params: {
    name: _aiFoundryName
    location: empty(aiFoundryLocation) ? location : aiFoundryLocation
    tags: tags
    kind: 'AIServices'
    customSubDomainName: _aiFoundryName
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
    disableLocalAuth: false
    sku: 'S0'
    deployments: deployments
    managedIdentities: {
      systemAssigned: true
    }
    diagnosticSettings: [
      {
        name: 'customSetting'
        logCategoriesAndGroups: [
          {
            category: 'RequestResponse'
          }
          {
            category: 'Audit'
          }
        ]
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
        workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
      }
    ]
    roleAssignments: [
      // See also https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/faq
      {
        roleDefinitionIdOrName: 'Cognitive Services OpenAI Contributor'
        principalId: azurePrincipalId
        principalType: 'User'
      }
      {
        principalId: azurePrincipalId
        roleDefinitionIdOrName: 'Cognitive Services User'
        principalType: 'User'
      }
    ]
  }
}

module aiProject 'modules/ai/project.bicep' = {
  name: '${deployment().name}_2'
  params: {
    location: location
    tags: tags
    name: _aiProjectName
    aiFoundryName: aiServices.outputs.name
  }
}

@description('Azure OpenAI Model Deployment Name - Executor Service')
var _aiDeploymentNameExecutor = deployments[0].name

var _aiFoundryApiEndpoint = aiServices.outputs.endpoint
// var _projectConnectionString = '${split(aiProject.outputs.discoveryUrl, '/')[2]};${subscription().subscriptionId};${resourceGroup().name};${aiProject.outputs.name}'

// ------------------------------ Storage Account ------------------------------
module storageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: '${deployment().name}-storageAccount'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    name: _storageAccountName
    kind: 'StorageV2'
    blobServices: {
      corsRules: [
        {
          allowedOrigins: [
            'https://mlworkspace.azure.ai'
            'https://ml.azure.com'
            'https://*.ml.azure.com'
            'https://ai.azure.com'
            'https://*.ai.azure.com'
            'https://mlworkspacecanary.azure.ai'
            'https://mlworkspace.azureml-test.net'
          ]
          allowedMethods: [
            'GET'
            'HEAD'
            'POST'
            'PUT'
            'DELETE'
            'OPTIONS'
            'PATCH'
          ]
          maxAgeInSeconds: 1800
          exposedHeaders: [
            '*'
          ]
          allowedHeaders: [
            '*'
          ]
        }
      ]
      containers: [
        {
          name: 'default'
          roleAssignments: [
          ]
        }
      ]
      roleAssignments: [
        {
          roleDefinitionIdOrName: 'Storage Blob Data Contributor'
          principalId: azurePrincipalId
        }
      ]
      deleteRetentionPolicy: {
        allowPermanentDelete: false
        enabled: false
      }
      shareDeleteRetentionPolicy: {
        enabled: true
        days: 7
      }
    }
  }
}


module aiSearchService 'br/public:avm/res/search/search-service:0.10.0' = if (useAiSearch && !useExistingAiSearch) {
  name: '${deployment().name}-aiSearchService'
  scope: resourceGroup()
  params: {
    name: _azureAiSearchName
    location: _azureAiSearchLocation
    tags: tags
    sku: aiSearchSkuName
    partitionCount: 1
    replicaCount: 1
    roleAssignments: [
      // See also https://learn.microsoft.com/en-us/azure/search/search-security-rbac
      {
        roleDefinitionIdOrName: 'Search Index Data Contributor'
        principalId: azurePrincipalId
        principalType: 'User'
      }
      {
        roleDefinitionIdOrName: 'Search Service Contributor'
        principalId: azurePrincipalId
        principalType: 'User'
      }
    ]
  }
}
/* --------------------------------- App  ----------------------------------- */



/* ------------------------------ CosmosDB  --------------------------------- */

/* module cosmosDbAccount 'br/public:avm/res/document-db/database-account:0.12.0' = {
  name: '${deployment().name}-cosmosDbAccount'
  params: {
    name: 'dddamin001'
    location: location
    sqlRoleAssignmentsPrincipalIds: [
      azurePrincipalId
      appIdentity.outputs.principalId
    ]
  }
} */

/* ---------------------------- Observability  ------------------------------ */

module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: '${deployment().name}-workspaceDeployment'
  params: {
    name: _logAnalyticsWorkspaceName
    location: location
    tags: tags
    dataRetention: 30
  }
}

module appInsightsComponent 'br/public:avm/res/insights/component:0.6.0' = {
  name: '${deployment().name}-applicationInsights'
  params: {
    name: _applicationInsightsName
    location: appInsightsLocation
    workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
  }
}

/* -------------------------------------------------------------------------- */
/*                                   OUTPUTS                                  */
/* -------------------------------------------------------------------------- */

// Outputs are automatically saved in the local azd environment .env file.
// To see these outputs, run `azd env get-values`,  or
// `azd env get-values --output json` for json output.
// To generate your own `.env` file run `azd env get-values > .env`

/* -------------------------- Feature flags ------------------------------- */

@description('If true, use and setup authentication with Azure Entra ID')
output USE_AUTHENTICATION bool = useAuthentication

@description('If true, deploy Azure AI Search Service')
output USE_AI_SEARCH bool = useAiSearch

@description('If true, reuse existing AI Foundry Service')
output USE_EXISTING_AI_FOUNDRY bool = useExistingAiFoundry

@description('If true, reuse existing Azure AI Search Service')
output USE_EXISTING_AI_SEARCH bool = useExistingAiSearch

/* --------------------------- Apps Deployment ----------------------------- */

@description('The endpoint of the container registry.') // necessary for azd deploy
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer

/* ------------------------ Authentication & RBAC ------------------------- */

@description('ID of the tenant we are deploying to')
output AZURE_AUTH_TENANT_ID string = authTenantId

@description('Principal ID of the user running the deployment')
output AZURE_PRINCIPAL_ID string = azurePrincipalId

@description('Application registration client ID')
output AZURE_CLIENT_APP_ID string = authClientAppId

/* -------------------------- Azure AI Foundry ----------------------------- */

// TODO: decide between the two names
@description('Azure AI Project connection string')
output AI_FOUNDRY_PROJECT_CONNECTION_STRING string = _projectConnectionString

@description('Azure AI Project Endpoint')
output AI_FOUNDRY_PROJECT_ENDPOINT string = _projectConnectionString


@description('AI Foundry service name')
output AI_FOUNDRY_NAME string = _aiFoundryName

@description('AI Foundry Project name')
output AI_FOUNDRY_PROJECT_NAME string = aiProject.outputs.name

@description('AI Foundry endpoint - Base URL for API calls to AI Foundry')
output AI_FOUNDRY_ENDPOINT string = _aiFoundryEndpoint


@description('AI Foundry API Version - API version to use when calling AI Foundry')
output AI_FOUNDRY_API_VERSION string = _aiFoundryApiVersion

// @description('Azure OpenAI Model Deployment Name - Executor Service')
output AI_DEPLOYMENT_NAME_EXECUTOR string = _aiDeploymentNameExecutor

// @description('Azure OpenAI Model Deployment Name - Utility Service')
// output UTILITY_AZURE_OPENAI_DEPLOYMENT_NAME string = _utilityAzureOpenAiDeploymentName

@description('JSON deployment configuration for the models')
output AI_FOUNDRY_DEPLOYMENTS object[] = deployments

//@description('Azure AI Content Understanding endpoint')
//output AZURE_CONTENT_UNDERSTANDING_ENDPOINT string = 'https://${_azureAiFoundryName}.services.ai.azure.com/'

/* ------------------------------ AI Search --------------------------------- */

@description('Azure AI Search service name')
output AZURE_AI_SEARCH_NAME string = _azureAiSearchName

@description('Azure AI Search service resource group name')
output AZURE_AI_SEARCH_RESOURCE_GROUP_NAME string = azureAiSearchResourceGroupName

@description('Azure AI Search deployment location')
output AZURE_AI_SEARCH_LOCATION string = azureAiSearchLocation

@description('Azure AI Search endpoint SKU name')
output AZURE_AI_SEARCH_SKU_NAME string = aiSearchSkuName

@description('Azure OpenAI endpoint - Base URL for API calls to Azure OpenAI')
// This environment variable name is used as a default by Semantic Kernel
output AZURE_AI_SEARCH_ENDPOINT string = _azureAiSearchEndpoint

/* -------------------------- Diagnostic Settings --------------------------- */

@description('Application Insights name')
output AZURE_APPLICATION_INSIGHTS_NAME string = appInsightsComponent.outputs.name

@description('Log Analytics Workspace name')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = logAnalyticsWorkspace.outputs.name

@description('Application Insights connection string')
output APPLICATIONINSIGHTS_CONNECTION_STRING string = appInsightsComponent.outputs.connectionString

@description('Semantic Kernel Diagnostics')
output SEMANTICKERNEL_EXPERIMENTAL_GENAI_ENABLE_OTEL_DIAGNOSTICS bool = true

@description('Semantic Kernel Diagnostics: if set, content of the messages is traced. Set to false in production')
output SEMANTICKERNEL_EXPERIMENTAL_GENAI_ENABLE_OTEL_DIAGNOSTICS_SENSITIVE bool = true
