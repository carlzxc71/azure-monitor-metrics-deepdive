locals {
  vm_names = ["vm-1", "vm-2", "vm-3"]
}

# Network Security Group
resource "azapi_resource" "nsg" {
  type      = "Microsoft.Network/networkSecurityGroups@2024-05-01"
  name      = "nsg-${var.environment}-${var.location_short}-connection-monitoring"
  location  = azapi_resource.rg.location
  parent_id = azapi_resource.rg.id
  body      = {}
}

# Virtual Network with Workload Subnet
resource "azapi_resource" "vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-${var.environment}-${var.location_short}-connection-monitoring"
  location  = azapi_resource.rg.location
  parent_id = azapi_resource.rg.id

  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.0.0.0/24"]
      }
      subnets = [
        {
          name = "snet-${var.environment}-${var.location_short}-connection-monitoring"
          properties = {
            addressPrefix = "10.0.0.0/26"
            networkSecurityGroup = {
              id = azapi_resource.nsg.id
            }
          }
        }
      ]
    }
  }
  response_export_values = {
    subnet_id = "properties.subnets[0].id"
  }
}

# Network Interfaces
resource "azapi_resource" "nic" {
  for_each  = toset(local.vm_names)
  type      = "Microsoft.Network/networkInterfaces@2024-05-01"
  name      = "nic-${each.key}-${var.environment}-${var.location_short}-connection-monitoring"
  location  = azapi_resource.rg.location
  parent_id = azapi_resource.rg.id

  body = {
    properties = {
      ipConfigurations = [
        {
          name = "ipconfig1"
          properties = {
            privateIPAllocationMethod = "Dynamic"
            subnet = {
              id = azapi_resource.vnet.output.subnet_id
            }
          }
        }
      ]
    }
  }
}

# Virtual Machines
resource "azapi_resource" "vm" {
  for_each  = toset(local.vm_names)
  type      = "Microsoft.Compute/virtualMachines@2024-03-01"
  name      = each.key
  location  = azapi_resource.rg.location
  parent_id = azapi_resource.rg.id

  body = {
    properties = {
      hardwareProfile = {
        vmSize = "Standard_B2s"
      }
      storageProfile = {
        imageReference = {
          publisher = "Canonical"
          offer     = "0001-com-ubuntu-server-jammy"
          sku       = "22_04-lts-gen2"
          version   = "latest"
        }
        osDisk = {
          createOption = "FromImage"
          managedDisk = {
            storageAccountType = "Standard_LRS"
          }
        }
      }
      osProfile = {
        computerName         = each.key
        adminUsername        = "azureadmin"
        adminPassword        = random_password.vm_password.result
        linuxConfiguration = {
          disablePasswordAuthentication = false
        }
      }
      networkProfile = {
        networkInterfaces = [
          {
            id = azapi_resource.nic[each.key].id
          }
        ]
      }
    }
  }
}

# Network Watcher Agent Extension (required for Connection Monitor)
resource "azapi_resource" "nw_agent" {
  for_each  = toset(local.vm_names)
  type      = "Microsoft.Compute/virtualMachines/extensions@2024-03-01"
  name      = "NetworkWatcherAgentLinux"
  location  = azapi_resource.rg.location
  parent_id = azapi_resource.vm[each.key].id

  body = {
    properties = {
      publisher               = "Microsoft.Azure.NetworkWatcher"
      type                    = "NetworkWatcherAgentLinux"
      typeHandlerVersion      = "1.4"
      autoUpgradeMinorVersion = true
    }
  }
}
