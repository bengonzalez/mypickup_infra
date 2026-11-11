#!/usr/bin/env bash
# One-time setup: create an App Registration + Service Principal for the
# mypickup_django GitHub Actions deploy pipeline, with OIDC federated
# credentials (no client secret stored anywhere) and least-privilege role
# assignments scoped to the resources created by `terraform apply`.
#
# Run this AFTER `terraform apply` has created the resource group, ACR, and
# Container App (it needs their names to scope the role assignments).
# Requires: az cli, logged in (az login) as a user who can create app
# registrations and role assignments.
#
# Usage:
#   ./scripts/bootstrap-oidc.sh <github-org> <github-repo> <branch>
# Example:
#   ./scripts/bootstrap-oidc.sh bengonzalez mypickup_django main

set -euo pipefail

GH_ORG="${1:?github org required, e.g. bengonzalez}"
GH_REPO="${2:?github repo required, e.g. mypickup_django}"
GH_BRANCH="${3:-main}"

APP_NAME="mypickup-django-deploy"
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

# Pull these from `terraform output` after apply.
RESOURCE_GROUP="$(terraform output -raw resource_group_name)"
ACR_NAME="$(terraform output -raw container_registry_name)"
CONTAINER_APP_NAME="$(terraform output -raw container_app_name)"

echo "Creating app registration: ${APP_NAME}"
APP_ID="$(az ad app create --display-name "${APP_NAME}" --query appId -o tsv)"
az ad sp create --id "${APP_ID}" >/dev/null

echo "Adding federated credential for repo:${GH_ORG}/${GH_REPO}:ref:refs/heads/${GH_BRANCH}"
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters "$(cat <<EOF
{
  "name": "github-actions-${GH_BRANCH}",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GH_ORG}/${GH_REPO}:ref:refs/heads/${GH_BRANCH}",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF
)"

ACR_ID="$(az acr show --name "${ACR_NAME}" --query id -o tsv)"
CONTAINER_APP_ID="$(az containerapp show --name "${CONTAINER_APP_NAME}" --resource-group "${RESOURCE_GROUP}" --query id -o tsv)"

echo "Granting AcrPush on ${ACR_NAME}"
az role assignment create --assignee "${APP_ID}" --role "AcrPush" --scope "${ACR_ID}" >/dev/null

echo "Granting Container Apps Contributor on ${CONTAINER_APP_NAME}"
az role assignment create --assignee "${APP_ID}" --role "Container Apps Contributor" --scope "${CONTAINER_APP_ID}" >/dev/null

cat <<EOF

Done. Set these as GitHub repo secrets on ${GH_ORG}/${GH_REPO}:
  AZURE_CLIENT_ID       = ${APP_ID}
  AZURE_TENANT_ID       = $(az account show --query tenantId -o tsv)
  AZURE_SUBSCRIPTION_ID = ${SUBSCRIPTION_ID}

And these as GitHub repo variables:
  ACR_NAME              = ${ACR_NAME}
  ACR_LOGIN_SERVER      = $(az acr show --name "${ACR_NAME}" --query loginServer -o tsv)
  RESOURCE_GROUP_NAME   = ${RESOURCE_GROUP}
  CONTAINER_APP_NAME    = ${CONTAINER_APP_NAME}
EOF
