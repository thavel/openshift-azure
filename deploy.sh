export WORKSPACE=$(pwd)/data
export LOCATION="westeurope"
export OPENSHIFTLOGIN="osadmin"
export OPENSHIFTPASS="Pass@word1"
export REPOSITORY="Microsoft/openshift-origin/master"
source config.env

# Prepare deployment env
if [ -d "${WORKSPACE}" ]
then
	echo "This script is not idempotent, please manually (re)move the local 'data' folder first!"
fi
mkdir data
pushd data

# Create Azure resource group
az group create -n ${RESOURCEGROUP} -l ${LOCATION}
export SCOPE=$(az group show --name ${RESOURCEGROUP} --query id -o tsv)

# Create SSH keys
ssh-keygen -f ${WORKSPACE}/openshift_rsa -t rsa -N ''
export PUBKEY=$(cat ${WORKSPACE}/openshift_rsa.pub)

# Store private key in a Azure vault
az keyvault create -n ${RESOURCEGROUP}-vault -g ${RESOURCEGROUP} -l ${LOCATION} --enabled-for-template-deployment true
az keyvault secret set --vault-name ${RESOURCEGROUP}-vault -n ${RESOURCEGROUP}-key --file ${WORKSPACE}/openshift_rsa

# Create Azure Service Principal
az ad sp create-for-rbac -n ${RESOURCEGROUP}-sp --password ${VAULTSECRET} --role contributor --scopes ${SCOPE}
export APPID=$(az ad sp list --display-name ${RESOURCEGROUP}-sp | jq '.[0].appId' --raw-output)

# Write template parameters
cat > ${WORKSPACE}/parameters.json <<EOF
{
	"$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
	"contentVersion": "1.0.0.0",
	"parameters": {
		"_artifactsLocation": {
			"value": "https://raw.githubusercontent.com/${REPOSITORY}/"
		},
		"osImage": {
			"value": "centos"
		},
		"masterVmSize": {
			"value": "Standard_DS2_v2"
		},
		"infraVmSize": {
			"value": "Standard_DS2_v2"
		},
		"nodeVmSize": {
			"value": "Standard_DS2_v2"
		},
		"openshiftClusterPrefix": {
			"value": "${CLUSTERPREFIX}"
		},
		"openshiftMasterPublicIpDnsLabel": {
			"value": "${RESOURCEGROUP}-master"
		},
		"infraLbPublicIpDnsLabel": {
			"value": "${RESOURCEGROUP}-node"
		},
		"masterInstanceCount": {
			"value": 1
		},
		"infraInstanceCount": {
			"value": 1
		},
		"nodeInstanceCount": {
			"value": 1
		},
		"dataDiskSize": {
			"value": 128
		},
		"adminUsername": {
			"value": "zenikadmin"
		},
		"openshiftPassword": {
			"value": "${OPENSHIFTPASS}"
		},
		"sshPublicKey": {
			"value": "${PUBKEY}"
		},
		"keyVaultResourceGroup": {
			"value": "${RESOURCEGROUP}"
		},
		"keyVaultName": {
			"value": "${RESOURCEGROUP}-vault"
		},
		"keyVaultSecret": {
			"value": "${RESOURCEGROUP}-key"
		},
		"aadClientId": {
			"value": "${APPID}"
		},
		"aadClientSecret": {
			"value": "${VAULTSECRET}"
		},
		"defaultSubDomainType": {
			"value": "xipio"
		},
		"defaultSubDomain": {
			"value": "none"
		}
	}
}
EOF

# Start deployment
curl -o ${WORKSPACE}/template.json https://raw.githubusercontent.com/${REPOSITORY}/azuredeploy.json
az group deployment create --resource-group ${RESOURCEGROUP} --template-file ${WORKSPACE}/template.json --parameters @${WORKSPACE}/parameters.json | tee output.json

# Read and print cluster info
export WEBACCESS=$(cat output.json | jq '.properties.outputs."openshift Console Url".value' --raw-output)
export SSHACCESS=$(cat output.json | jq '.properties.outputs."openshift Master SSH".value' --raw-output)
cat <<EOF
    * Web console: ${WEBACCESS}
    * SSH: ${SSHACCESS}
EOF

popd
