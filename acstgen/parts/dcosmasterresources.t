    {
      "apiVersion": "[variables('apiVersionStorage')]", 
      "dependsOn": [
        "[concat('Microsoft.Network/publicIPAddresses/', variables('masterPublicIPAddressName'))]"
      ], 
      "location": "[variables('storageLocation')]", 
      "name": "[variables('masterStorageAccountName')]", 
      "properties": {
        "accountType": "[variables('vmSizesMap')[variables('masterVMSize')].storageAccountType]"
      }, 
      "type": "Microsoft.Storage/storageAccounts"
    }, 
    {
      "apiVersion": "[variables('apiVersionStorage')]", 
      "dependsOn": [
        "[concat('Microsoft.Network/publicIPAddresses/', variables('masterPublicIPAddressName'))]"
      ], 
      "location": "[variables('storageLocation')]", 
      "name": "[variables('masterStorageAccountExhibitorName')]", 
      "properties": {
        "accountType": "Standard_LRS"
      }, 
      "type": "Microsoft.Storage/storageAccounts"
    }, 
    {
      "apiVersion": "[variables('apiVersionDefault')]", 
      "dependsOn": [
      ], 
      "location": "[resourceGroup().location]", 
      "name": "[variables('virtualNetworkName')]", 
      "properties": {
        "addressSpace": {
          "addressPrefixes": [
            {{.VNETAddressPrefixes}}
          ]
        }, 
        "subnets": [
          {{.VNETSubnets}}
        ]
      }, 
      "type": "Microsoft.Network/virtualNetworks"
    }, 
    {
      "apiVersion": "[variables('apiVersionDefault')]", 
      "location": "[resourceGroup().location]", 
      "name": "[variables('masterAvailabilitySet')]", 
      "properties": {}, 
      "type": "Microsoft.Compute/availabilitySets"
    }, 
    {
      "apiVersion": "[variables('apiVersionDefault')]", 
      "location": "[resourceGroup().location]", 
      "name": "[variables('masterPublicIPAddressName')]", 
      "properties": {
        "dnsSettings": {
          "domainNameLabel": "[variables('masterEndpointDNSNamePrefix')]"
        }, 
        "publicIPAllocationMethod": "Dynamic"
      }, 
      "type": "Microsoft.Network/publicIPAddresses"
    }, 
    {
      "apiVersion": "[variables('apiVersionDefault')]", 
      "dependsOn": [
        "[concat('Microsoft.Network/publicIPAddresses/', variables('masterPublicIPAddressName'))]"
      ], 
      "location": "[resourceGroup().location]", 
      "name": "[variables('masterLbName')]", 
      "properties": {
        "backendAddressPools": [
          {
            "name": "[variables('masterLbBackendPoolName')]"
          }
        ], 
        "frontendIPConfigurations": [
          {
            "name": "[variables('masterLbIPConfigName')]", 
            "properties": {
              "publicIPAddress": {
                "id": "[resourceId('Microsoft.Network/publicIPAddresses',variables('masterPublicIPAddressName'))]"
              }
            }
          }
        ]
      }, 
      "type": "Microsoft.Network/loadBalancers"
    }, 
    {
      "apiVersion": "[variables('apiVersionDefault')]", 
      "copy": {
        "count": "[variables('masterCount')]", 
        "name": "masterLbLoopNode"
      }, 
      "dependsOn": [
        "[variables('masterLbID')]"
      ], 
      "location": "[resourceGroup().location]", 
      "name": "[concat(variables('masterLbName'), '/', 'SSH-', variables('masterVMNamePrefix'), copyIndex())]", 
      "properties": {
        "backendPort": 22, 
        "enableFloatingIP": false, 
        "frontendIPConfiguration": {
          "id": "[variables('masterLbIPConfigID')]"
        }, 
        "frontendPort": "[copyIndex(2200)]", 
        "protocol": "tcp"
      }, 
      "type": "Microsoft.Network/loadBalancers/inboundNatRules"
    }, 
    {
      "apiVersion": "[variables('apiVersionDefault')]", 
      "location": "[resourceGroup().location]", 
      "name": "[variables('masterNSGName')]", 
      "properties": {
        "securityRules": [
          {
            "name": "ssh", 
            "properties": {
              "access": "Allow", 
              "description": "Allow SSH", 
              "destinationAddressPrefix": "*", 
              "destinationPortRange": "22", 
              "direction": "Inbound", 
              "priority": 200, 
              "protocol": "Tcp", 
              "sourceAddressPrefix": "*", 
              "sourcePortRange": "*"
            }
          }
        ]
      }, 
      "type": "Microsoft.Network/networkSecurityGroups"
    }, 
    {
      "apiVersion": "[variables('apiVersionDefault')]", 
      "copy": {
        "count": "[variables('masterCount')]", 
        "name": "nicLoopNode"
      }, 
      "dependsOn": [
        "[variables('masterLbID')]", 
        "[variables('vnetID')]", 
        "[concat(variables('masterLbID'),'/inboundNatRules/SSH-',variables('masterVMNamePrefix'),copyIndex())]", 
        "[variables('masterNSGID')]"
      ], 
      "location": "[resourceGroup().location]", 
      "name": "[concat(variables('masterVMNamePrefix'), 'nic-', copyIndex())]", 
      "properties": {
        "ipConfigurations": [
          {
            "name": "ipConfigNode", 
            "properties": {
              "loadBalancerBackendAddressPools": [
                {
                  "id": "[concat(variables('masterLbID'), '/backendAddressPools/', variables('masterLbBackendPoolName'))]"
                }
              ], 
              "loadBalancerInboundNatRules": [
                {
                  "id": "[concat(variables('masterLbID'),'/inboundNatRules/SSH-',variables('masterVMNamePrefix'),copyIndex())]"
                }
              ], 
              "privateIPAddress": "[concat(split(variables('masterSubnet'),'0/24')[0], copyIndex(variables('masterFirstAddr')))]", 
              "privateIPAllocationMethod": "Static", 
              "subnet": {
                "id": "[variables('masterSubnetRef')]"
              }
            }
          }
        ], 
        "networkSecurityGroup": {
          "id": "[variables('masterNSGID')]"
        }
      }, 
      "type": "Microsoft.Network/networkInterfaces"
    }, 
    {
      "apiVersion": "[variables('apiVersionDefault')]", 
      "copy": {
        "count": "[variables('masterCount')]", 
        "name": "vmLoopNode"
      }, 
      "dependsOn": [
        "[concat('Microsoft.Network/networkInterfaces/', variables('masterVMNamePrefix'), 'nic-', copyIndex())]", 
        "[concat('Microsoft.Compute/availabilitySets/',variables('masterAvailabilitySet'))]", 
        "[variables('masterStorageAccountName')]", 
        "[variables('masterStorageAccountExhibitorName')]"
      ], 
      "location": "[resourceGroup().location]", 
      "name": "[concat(variables('masterVMNamePrefix'), copyIndex())]", 
      "properties": {
        "availabilitySet": {
          "id": "[resourceId('Microsoft.Compute/availabilitySets',variables('masterAvailabilitySet'))]"
        }, 
        "diagnosticsProfile": {
          "bootDiagnostics": {
            "enabled": "true", 
            "storageUri": "[reference(concat('Microsoft.Storage/storageAccounts/', variables('masterStorageAccountName')), variables('apiVersionStorage')).primaryEndpoints.blob]"
          }
        }, 
        "hardwareProfile": {
          "vmSize": "[variables('masterVMSize')]"
        }, 
        "networkProfile": {
          "networkInterfaces": [
            {
              "id": "[resourceId('Microsoft.Network/networkInterfaces',concat(variables('masterVMNamePrefix'), 'nic-', copyIndex()))]"
            }
          ]
        }, 
        "osProfile": {
          "adminUsername": "[variables('adminUsername')]", 
          "computername": "[concat(variables('masterVMNamePrefix'), copyIndex())]", 
          "customData": "[base64(concat({{if IsDCOS173}}{{template "dcoscustomdata173.t" .}}{{else if IsDCOS184}}{{template "dcoscustomdata184.t" .}}{{end}}))]", 
          "linuxConfiguration": {
            "disablePasswordAuthentication": "true", 
            "ssh": {
                "publicKeys": [
                    {
                        "keyData": "[variables('sshRSAPublicKey')]", 
                        "path": "[variables('sshKeyPath')]"
                    }
                ]
            }
          }
        }, 
        "storageProfile": {
          "imageReference": {
            "offer": "[variables('osImageOffer')]", 
            "publisher": "[variables('osImagePublisher')]", 
            "sku": "[variables('osImageSKU')]", 
            "version": "[variables('osImageVersion')]"
          }, 
          "osDisk": {
            "caching": "ReadWrite", 
            "createOption": "FromImage", 
            "name": "[concat(variables('masterVMNamePrefix'), copyIndex(),'-osdisk')]", 
            "vhd": {
              "uri": "[concat(reference(concat('Microsoft.Storage/storageAccounts/',variables('masterStorageAccountName')),variables('apiVersionStorage')).primaryEndpoints.blob,'vhds/',variables('masterVMNamePrefix'),copyIndex(),'-osdisk.vhd')]"
            }
          }
        }
      }, 
      "type": "Microsoft.Compute/virtualMachines"
    }, 
    {
      "apiVersion": "[variables('apiVersionDefault')]", 
      "dependsOn": [
        "[concat('Microsoft.Compute/virtualMachines/', variables('masterVMNamePrefix'), sub(variables('masterCount'), 1))]"
      ], 
      "location": "[resourceGroup().location]", 
      "name": "[concat(variables('masterVMNamePrefix'), sub(variables('masterCount'), 1), '/waitforleader')]", 
      "properties": {
        "autoUpgradeMinorVersion": true, 
        "publisher": "Microsoft.OSTCExtensions", 
        "settings": {
          "commandToExecute": "sh -c 'until ping -c1 leader.mesos;do echo waiting for leader.mesos;sleep 15;done;echo leader.mesos up'"
        }, 
        "type": "CustomScriptForLinux", 
        "typeHandlerVersion": "1.4"
      }, 
      "type": "Microsoft.Compute/virtualMachines/extensions"
    }