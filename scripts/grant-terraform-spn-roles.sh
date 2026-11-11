#!/usr/bin/env bash
# One-time setup for the `.github/workflows/terraform.yml` pipeline.
#
# Assumes the App Registration/Service Principal and its OIDC federated
# credential (trusting GitHub Actions on this repo) already exist — this
# only grants the roles that SPN needs and prints what to put in the
# mypickup_infra repo's GitHub secrets. It does NOT create the app or any
# federated credential.
#
# This SPN needs to be more privileged than the app-deploy SPN in
# scripts/bootstrap-oidc.sh: it has to create the resource group itself
# (first-ever apply starts from nothing) and create the AcrPull role
# assignment Terraform defines — plain "Contributor" explicitly cannot
# create role assignments, so it also needs a role-assignment permission.
# For simplicity this grants both at subscription scope, which also covers
# the pre-existing backend state storage account (rg-storage-backend/
# stgbackendtfbg) without a separate role assignment. That's broad for a
# shared/production subscription — narrow it to a resource-group scope
# (after pre-creating the RG) if that matters to you.
#
# Requires: az cli, logged in (az login) as a user who can create
# subscription-level role assignments (e.g. Owner).
#
# Usage:
#   ./scripts/grant-terraform-spn-roles.sh <client-id-or-object-id>
# Example:
#   ./scripts/grant-terraform-spn-roles.sh 11111111-2222-3333-4444-555555555555

set -euo pipefail

SPN_ID="${1:?SPN client ID (appId) or object ID required}"
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

echo "Granting Contributor at subscription scope"
az role assignment create \
  --assignee "${SPN_ID}" \
  --role "Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}" >/dev/null

echo "Granting Role Based Access Control Administrator at subscription scope (needed to create the AcrPull role assignment)"
az role assignment create \
  --assignee "${SPN_ID}" \
  --role "Role Based Access Control Administrator" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}" >/dev/null

cat <<EOF

Done. Set these as GitHub repo secrets on mypickup_infra:
  AZURE_CLIENT_ID       = <the SPN's client/application ID>
  AZURE_TENANT_ID       = $(az account show --query tenantId -o tsv)
  AZURE_SUBSCRIPTION_ID = ${SUBSCRIPTION_ID}
  DJANGO_SECRET_KEY     = <a long random value>
  EMAIL_USER            = <gmail smtp user, optional>
  EMAIL_PASS            = <gmail smtp app password, optional>
EOF
