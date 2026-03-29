terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "2.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azapi" {}

resource "random_password" "vm_password" {
  length           = 24
  special          = true
  override_special = "!@#$%&*"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

# Resource Group
resource "azapi_resource" "rg" {
  type     = "Microsoft.Resources/resourceGroups@2024-03-01"
  name     = "rg-${var.environment}-${var.location_short}-connection-monitoring"
  location = var.location
  body     = {}
}

# Network Watcher (already exists in the subscription)
data "azapi_resource" "network_watcher" {
  type        = "Microsoft.Network/networkWatchers@2024-05-01"
  resource_id = "/subscriptions/${var.subscription_id}/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_${var.location}"
}

# Connection Monitor
resource "azapi_resource" "connection_monitor" {
  type      = "Microsoft.Network/networkWatchers/connectionMonitors@2024-05-01"
  name      = "cm-${var.environment}-${var.location_short}-connection-monitoring"
  location  = azapi_resource.rg.location
  parent_id = data.azapi_resource.network_watcher.id

  body = {
    properties = {
      endpoints = [
        # Source endpoints — Azure VMs
        {
          name       = "src-vm-1"
          type       = "AzureVM"
          resourceId = azapi_resource.vm["vm-1"].id
        },
        {
          name       = "src-vm-2"
          type       = "AzureVM"
          resourceId = azapi_resource.vm["vm-2"].id
        },
        {
          name       = "src-vm-3"
          type       = "AzureVM"
          resourceId = azapi_resource.vm["vm-3"].id
        },

        # Destination endpoints — External websites
        {
          name    = "dst-google"
          type    = "ExternalAddress"
          address = "www.google.com"
        },
        {
          name    = "dst-bing"
          type    = "ExternalAddress"
          address = "www.bing.com"
        },
        {
          name    = "dst-github"
          type    = "ExternalAddress"
          address = "www.github.com"
        },
        {
          name    = "dst-lindbergtech"
          type    = "ExternalAddress"
          address = "www.lindbergtech.com"
        }
      ]

      testConfigurations = [
        {
          name             = "tcp-443"
          testFrequencySec = 60
          protocol         = "Tcp"
          tcpConfiguration = {
            port              = 443
            disableTraceRoute = false
          }
          successThreshold = {
            checksFailedPercent = 20
            roundTripTimeMs     = 100
          }
        }
      ]

      testGroups = [
        {
          name               = "tg-tcp443"
          sources            = ["src-vm-1", "src-vm-2", "src-vm-3"]
          destinations       = ["dst-google", "dst-bing", "dst-github", "dst-lindbergtech"]
          testConfigurations = ["tcp-443"]
          disable            = false
        }
      ]
    }
  }

  depends_on = [azapi_resource.nw_agent]
}
