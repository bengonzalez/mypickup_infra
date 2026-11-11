locals {
  name_prefix        = "${var.project_name}-${var.environment}"
  container_app_name = "ca-${local.name_prefix}"
  fqdn               = "${local.container_app_name}.${azurerm_container_app_environment.main.default_domain}"
}

# Suffix for globally-unique names (storage account, ACR).
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.name_prefix}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_container_registry" "main" {
  name                = "acr${var.project_name}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
}

# Storage account backing Django's persistent media uploads (MEDIA_ROOT_PATH)
# and the SQLite database file (SQLITE_PATH). The Container App's local
# filesystem is otherwise ephemeral, so without this, both uploaded profile
# pics and the database would be wiped on every scale-to-zero/restart.
resource "azurerm_storage_account" "media" {
  name                     = "st${var.project_name}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
}

resource "azurerm_storage_share" "media" {
  name               = "media"
  storage_account_id = azurerm_storage_account.media.id
  quota              = var.media_share_quota_gb
}

resource "azurerm_container_app_environment_storage" "media" {
  name                         = "media"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.media.name
  share_name                   = azurerm_storage_share.media.name
  access_key                   = azurerm_storage_account.media.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app" "main" {
  name                         = local.container_app_name
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = "System"
  }

  secret {
    name  = "django-secret-key"
    value = var.django_secret_key
  }

  secret {
    name  = "email-user"
    value = var.email_user
  }

  secret {
    name  = "email-pass"
    value = var.email_pass
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "mypickup-django"
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name        = "DJANGO_SECRET_KEY"
        secret_name = "django-secret-key"
      }

      env {
        name  = "DJANGO_DEBUG"
        value = var.django_debug
      }

      env {
        name  = "DJANGO_ALLOWED_HOSTS"
        value = local.fqdn
      }

      env {
        name  = "DJANGO_CSRF_TRUSTED_ORIGINS"
        value = "https://${local.fqdn}"
      }

      env {
        name  = "MEDIA_ROOT_PATH"
        value = "/mnt/media"
      }

      env {
        name  = "SQLITE_PATH"
        value = "/mnt/media/db.sqlite3"
      }

      env {
        name        = "EMAIL_USER"
        secret_name = "email-user"
      }

      env {
        name        = "EMAIL_PASS"
        secret_name = "email-pass"
      }

      volume_mounts {
        name = "media"
        path = "/mnt/media"
      }
    }

    volume {
      name         = "media"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.media.name
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  lifecycle {
    # The deploy pipeline updates the running image directly via
    # `az containerapp update`; don't let `terraform apply` revert it
    # back to the placeholder.
    ignore_changes = [
      template[0].container[0].image,
    ]
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}
