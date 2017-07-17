# Openshift - Azure

Automated script to deploy an Openshift Origin (currently 1.5.1) cluster to Microsoft Azure.

## Requirements
* [Azure CLI](https://docs.microsoft.com/fr-fr/cli/azure/install-azure-cli) >= 2.0
* [jq](https://stedolan.github.io/jq/) >= 1.5
* curl

## Getting started

1. Copy or rename `config.template.env` into `config.env`.
2. Set the `RESOURCEGROUP`, `CLUSTERPREFIX` and `VAULTSECRET` with the desired values.
3. Run `./deploy.sh`.
4. This script output a `$CLUSTERURL` env variable.

## Security

Reach your cluster using either the [Openshift CLI](https://github.com/openshift/origin/releases) (>= 1.5) or the web console (with script's output values) and the `$OPENSHIFTLOGIN`/`$OPENSHIFTPASS` (please note that _you should change this password at once_!)
