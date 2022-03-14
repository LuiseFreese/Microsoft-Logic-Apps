param LogicAppName string = 'ReceiveIntuneServiceHealthMessages'

@description('Name of the Key Vault that contains the App Registration Secret')
param keyvault_name string

@description('Teams webhook URI')
param webhook_uri string

var KeyvaultConnectionName_var = 'keyvault-${LogicAppName}'

resource LogicAppName_resource 'Microsoft.Logic/workflows@2017-07-01' = {
  name: LogicAppName
  location: resourceGroup().location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        Recurrence: {
          recurrence: {
            frequency: 'Hour'
            interval: 1
          }
          evaluatedRecurrence: {
            frequency: 'Hour'
            interval: 1
          }
          type: 'Recurrence'
        }
      }
      actions: {
        For_each: {
          foreach: '@body(\'Parse_JSON_Select_values\')'
          actions: {
            Condition: {
              actions: {
                'HTTP_POST_Teams_Webhook_klapwijk.nu': {
                  runAfter: {}
                  type: 'Http'
                  inputs: {
                    body: {
                      text: '**Title:** @{items(\'For_each\')[\'Title\']}\n\n **ID:** @{items(\'For_each\')[\'ID\']}\n\n **Impact Description:** @{items(\'For_each\')[\'Impact Description\']}\n\n **Classification:** @{items(\'For_each\')[\'Classification\']}\n\n **Start Time:** @{items(\'For_each\')[\'Start Date Time\']}\n\n **Last Modified Time:** @{items(\'For_each\')[\'Last Modified Time\']}\n\n **Status:** @{items(\'For_each\')[\'Status\']}\n\n **Is Resolved:** @{items(\'For_each\')[\'Is Resolved\']}'
                      title: '@{items(\'For_each\')[\'ID\']} '
                    }
                    headers: {
                      'Content-Type': 'application/json'
                    }
                    method: 'POST'
                    uri: webhook_uri
                  }
                }
              }
              runAfter: {}
              expression: {
                or: [
                  {
                    greater: [
                      '@items(\'For_each\')[\'Last Modified Time\']'
                      '@addHours(utcNow(),-1)'
                    ]
                  }
                ]
              }
              type: 'If'
            }
          }
          runAfter: {
            Parse_JSON_Select_values: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        HTTP_GET_Service_Messages: {
          runAfter: {
            'client-secret': [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              audience: 'https://graph.microsoft.com'
              clientId: '@body(\'client-id\')?[\'value\']'
              secret: '@body(\'client-secret\')?[\'value\']'
              tenant: '@body(\'tenant-id\')?[\'value\']'
              type: 'ActiveDirectoryOAuth'
            }
            method: 'GET'
            uri: 'https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/issues?$filter=service%20eq%20\'Microsoft%20Intune\''
          }
        }
        Parse_JSON_Select_values: {
          runAfter: {
            Select_values: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Select_values\')'
            schema: {
              items: {
                properties: {
                  Classification: {
                    type: 'string'
                  }
                  ID: {
                    type: 'string'
                  }
                  'Impact Description': {
                    type: 'string'
                  }
                  'Is Resolved': {
                    type: 'boolean'
                  }
                  'Last Modified Time': {
                    type: 'string'
                  }
                  'Start Date Time': {
                    type: 'string'
                  }
                  Status: {
                    type: 'string'
                  }
                  Title: {
                    type: 'string'
                  }
                }
                required: [
                  'Classification'
                  'ID'
                  'Last Modified Time'
                  'Start Date Time'
                  'Status'
                  'Title'
                  'Impact Description'
                  'Is Resolved'
                ]
                type: 'object'
              }
              type: 'array'
            }
          }
        }
        Select_values: {
          runAfter: {
            HTTP_GET_Service_Messages: [
              'Succeeded'
            ]
          }
          type: 'Select'
          inputs: {
            from: '@body(\'HTTP_GET_Service_Messages\')?[\'value\']'
            select: {
              Classification: '@item()?[\'Classification\']'
              ID: '@item()?[\'Id\']'
              'Impact Description': '@item()?[\'impactDescription\']'
              'Is Resolved': '@item()?[\'isResolved\']'
              'Last Modified Time': '@item()?[\'lastModifiedDateTime\']'
              'Start Date Time': '@item()?[\'startDateTime\']'
              Status: '@item()?[\'Status\']'
              Title: '@item()?[\'Title\']'
            }
          }
        }
        'client-id': {
          runAfter: {
            'tenant-id': [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/secrets/@{encodeURIComponent(\'client-id\')}/value'
          }
        }
        'client-secret': {
          runAfter: {
            'client-id': [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/secrets/@{encodeURIComponent(\'client-secret\')}/value'
          }
        }
        'tenant-id': {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/secrets/@{encodeURIComponent(\'tenant-id\')}/value'
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          keyvault: {
            connectionId: KeyvaultConnectionName.id
            connectionName: KeyvaultConnectionName_var
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/keyvault'
          }
        }
      }
    }
  }
}

resource KeyvaultConnectionName 'Microsoft.Web/connections@2016-06-01' = {
  name: KeyvaultConnectionName_var
  location: resourceGroup().location
  properties: {
    displayName: KeyvaultConnectionName_var
    parameterValues: {
      vaultName: keyvault_name
    }
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/keyvault'
    }
  }
}