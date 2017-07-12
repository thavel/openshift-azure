#!/usr/bin/env bash

export WORKSPACE=$(pwd)
export OPENSHIFTPASS="Pass@word1"
source config.env

# Create Azure resource group
az group create -n ${RESOURCEGROUP} -l ${LOCATION}
export SCOPE=$(az group show --name ${RESOURCEGROUP} --query id -o tsv)

# Create SSH keys
ssh-keygen -f ${WORKSPACE}/openshift_rsa -t rsa -N ''
export PUBKEY=$(cat ${WORKSPACE}/openshift_rsa.pub)

# Store private key in a Azure vault
az keyvault create -n ${RESOURCEGROUP}Vault -g ${RESOURCEGROUP} -l ${LOCATION} --enabled-for-template-deployment true
az keyvault secret set --vault-name ${RESOURCEGROUP}Vault -n ${RESOURCEGROUP}Key --file ${WORKSPACE}/openshift_rsa

# Create Azure Service Principal
az ad sp create-for-rbac -n ${RESOURCEGROUP}Sp --password ${VAULTSECRET} --role contributor --scopes ${SCOPE}
export APPID=$(az ad sp list --display-name ${RESOURCEGROUP}Sp | jq ".[0].appId" --raw-output)

# Write template parameters
cat > ${WORKSPACE}/parameters.json <<EOF
{
	"$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
	"contentVersion": "1.0.0.0",
	"parameters": {
		"_artifactsLocation": {
			"value": "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/openshift-origin-rhel/"
		},
		"masterVmSize": {
			"value": "Standard_DS3_v2"
		},
		"nodeVmSize": {
			"value": "Standard_DS3_v2"
		},
		"osImage": {
			"value": "centos"
		},
		"openshiftMasterHostname": {
			"value": "changeme"
		},
		"openshiftMasterPublicIpDnsLabelPrefix": {
			"value": "GEN-UNIQUE"
		},
		"nodeLbPublicIpDnsLabelPrefix": {
			"value": "GEN-UNIQUE"
		},
		"nodePrefix": {
			"value": "changeme"
		},
		"nodeInstanceCount": {
			"value": 1
		},
		"adminUsername": {
			"value": "changeme"
		},
		"adminPassword": {
			"value": "changeme"
		},
		"sshPublicKey": {
			"value": "GEN-SSH-PUB-KEY"
		},
		"subscriptionId": {
			"value": "changeme"
		},
		"keyVaultResourceGroup": {
			"value": "changeme"
		},
		"keyVaultName": {
			"value": "changeme"
		},
		"keyVaultSecret": {
			"value": "changeme"
		},
		"defaultSubDomainType": {
			"value": "xipio"
		},
		"defaultSubDomain": {
			"value": "changeme"
		}
	}
}
EOF

# Start deployment
curl -o ${WORKSPACE}/template.json https://raw.githubusercontent.com/Microsoft/openshift-origin/master/azuredeploy.json
az group deployment create --resource-group ${RESOURCEGROUP} --template-file ${WORKSPACE}/template.json --parameters @${WORKSPACE}/parameters.json
