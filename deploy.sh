#!/usr/bin/env bash

export REPOSITORY="https://raw.githubusercontent.com/thavel/openshift-azure/master/"
export WORKSPACE=$(pwd)/tmp
export OPENSHIFTPASS="Pass@word1"
source config.env

# Account subscription
export SUBID=$(az account show --query id --output tsv)

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
			"value": "${REPOSITORY}"
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
			"value": "${CLUSTERPREFIX}m"
		},
		"openshiftMasterPublicIpDnsLabelPrefix": {
			"value": "${RESOURCEGROUP}master"
		},
		"nodeLbPublicIpDnsLabelPrefix": {
			"value": "${RESOURCEGROUP}node"
		},
		"nodePrefix": {
			"value": "${CLUSTERPREFIX}"
		},
		"nodeInstanceCount": {
			"value": 1
		},
		"adminUsername": {
			"value": "${ADMINLOGIN}"
		},
		"adminPassword": {
			"value": "${ADMINPASS}"
		},
		"sshPublicKey": {
			"value": "${PUBKEY}"
		},
		"subscriptionId": {
			"value": "${SUBID}"
		},
		"keyVaultResourceGroup": {
			"value": "${RESOURCEGROUP}"
		},
		"keyVaultName": {
			"value": "${RESOURCEGROUP}Vault"
		},
		"keyVaultSecret": {
			"value": "${RESOURCEGROUP}Key"
		},
		"defaultSubDomainType": {
			"value": "xipio"
		},
		"defaultSubDomain": {
			"value": "ignored"
		}
	}
}
EOF

# Start deployment
#curl -o ${WORKSPACE}/template.json ${REPOSITORY}/template.json
#az group deployment create --resource-group ${RESOURCEGROUP} --template-file ${WORKSPACE}/template.json --parameters @${WORKSPACE}/parameters.json
