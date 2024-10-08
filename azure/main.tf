
resource "azurerm_resource_group" "resource_group" {
  name       = "fiap-tech-challenge-payment-group"
  location   = var.location

  tags = {
    environment = var.environment
  }
}

resource "azurerm_cosmosdb_account" "sanduba_payment_database_account" {
  name                          = "sanduba-payment-cosmosdb"
  location                      = azurerm_resource_group.resource_group.location
  resource_group_name           = azurerm_resource_group.resource_group.name
  offer_type                    = "Standard"
  enable_free_tier              = true
  kind                          = "MongoDB"
  public_network_access_enabled = true

  enable_automatic_failover = false

  mongo_server_version = 4.2

  consistency_policy {
    consistency_level = "BoundedStaleness"
  }

  geo_location {
    location          = azurerm_resource_group.resource_group.location
    failover_priority = 0
    zone_redundant    = false
  }

  tags = {
    environment = azurerm_resource_group.resource_group.tags["environment"]
  }
}

resource "azurerm_cosmosdb_mongo_database" "sanduba_payment_database" {
  name                = "sanduba-payment-database"
  resource_group_name = azurerm_cosmosdb_account.sanduba_payment_database_account.resource_group_name
  account_name        = azurerm_cosmosdb_account.sanduba_payment_database_account.name
}

resource "azurerm_cosmosdb_mongo_collection" "sanduba_payment_database_collection" {
  name                = "sanduba-payment-database-collection"
  resource_group_name = azurerm_cosmosdb_mongo_database.sanduba_payment_database.resource_group_name
  account_name        = azurerm_cosmosdb_mongo_database.sanduba_payment_database.account_name
  database_name       = azurerm_cosmosdb_mongo_database.sanduba_payment_database.name

  default_ttl_seconds = "777"
  throughput          = 400

  index {
    keys   = ["_id"]
    unique = true
  }
}

data "azurerm_servicebus_namespace" "order_topic_namespace" {
  name                = "fiap-tech-challenge-order-topic-namespace"
  resource_group_name = "fiap-tech-challenge-order-group"
}

data "azurerm_servicebus_topic" "order_topic" {
  name         = "fiap-tech-challenge-order-topic"
  namespace_id = data.azurerm_servicebus_namespace.order_topic_namespace.id
}

data "azurerm_servicebus_topic_authorization_rule" "order_topic_manager" {
  name     = "${data.azurerm_servicebus_topic.order_topic.name}-manager"
  topic_id = data.azurerm_servicebus_topic.order_topic.id
}

resource "azurerm_service_plan" "payment_plan" {
  name                = "payment-app-service-plan"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  os_type             = "Linux"
  sku_name            = "B1"

  tags = {
    environment = azurerm_resource_group.resource_group.tags["environment"]
  }
}

data "azurerm_storage_account" "storage_account_terraform" {
  name                = "sandubaterraform"
  resource_group_name = var.main_resource_group
}

data "azurerm_virtual_network" "virtual_network" {
  name                = "fiap-tech-challenge-network"
  resource_group_name = var.main_resource_group
}

data "azurerm_subnet" "api_subnet" {
  name                 = "fiap-tech-challenge-payment-subnet"
  virtual_network_name = data.azurerm_virtual_network.virtual_network.name
  resource_group_name  = data.azurerm_virtual_network.virtual_network.resource_group_name
}

resource "azurerm_linux_function_app" "linux_function" {
  name                        = "sanduba-payment-function"
  resource_group_name         = azurerm_resource_group.resource_group.name
  location                    = azurerm_resource_group.resource_group.location
  storage_account_name        = data.azurerm_storage_account.storage_account_terraform.name
  storage_account_access_key  = data.azurerm_storage_account.storage_account_terraform.primary_access_key
  service_plan_id             = azurerm_service_plan.payment_plan.id
  https_only                  = true
  functions_extension_version = "~4"

  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE        = false
    FUNCTIONS_EXTENSION_VERSION                = "~4"
    "MongoSettings__ConnectionString"          = azurerm_cosmosdb_account.sanduba_payment_database_account.primary_mongodb_connection_string
    "MongoSettings__DatabaseName"              = "sanduba-payment-database"
    "MongoSettings__CollectionName"            = "sanduba-payment-database-collection"
    "MercadoPagoSettings__BaseUrl"             = "https://api.mercadopago.com"
    "MercadoPagoSettings__NotificationUrl"     = "https://sanduba-payment-function.azurewebsites.net/api/PaymentProviderUpdate"
    "MercadoPagoSettings__AuthenticationToken" = var.mercadopago_authentication_token
    "MercadoPagoSettings__UserId"              = var.mercadopago_user_id
    "MercadoPagoSettings__CashierId"           = var.mercadopago_cashier_id
    "BrokerSettings__TopicConnectionString"    = data.azurerm_servicebus_topic_authorization_rule.order_topic_manager.primary_connection_string
    "BrokerSettings__TopicName"                = data.azurerm_servicebus_topic.order_topic.name
  }

  site_config {
    always_on = true
    application_stack {
      docker {
        registry_url = "https://index.docker.io"
        image_name   = "cangelosilima/sanduba-payment-api"
        image_tag    = "latest"
      }
    }
  }

  virtual_network_subnet_id = data.azurerm_subnet.api_subnet.id

  tags = {
    environment = azurerm_resource_group.resource_group.tags["environment"]
  }
}

data "azurerm_storage_account" "log_storage_account" {
  name                = "sandubalog"
  resource_group_name = var.main_resource_group
}

data "azurerm_log_analytics_workspace" "log_workspace" {
  name                = "fiap-tech-challenge-observability-workspace"
  resource_group_name = var.main_resource_group
}

resource "azurerm_monitor_diagnostic_setting" "function_monitor" {
  name                       = "fiap-tech-challenge-payment-monitor"
  target_resource_id         = azurerm_linux_function_app.linux_function.id
  storage_account_id         = data.azurerm_storage_account.log_storage_account.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.log_workspace.id

  enabled_log {
    category = "FunctionAppLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

output "sanduba_payment_url" {
  sensitive = false
  value     = "https://${azurerm_linux_function_app.linux_function.default_hostname}/api"
}