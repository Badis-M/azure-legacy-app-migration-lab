#!/usr/bin/env bash

set -euo pipefail

TFSTATE_RG="${TFSTATE_RG:-rg-tfstate-azure-migration-lab-dev}"
TFSTATE_LOCATION="${TFSTATE_LOCATION:-francecentral}"
TFSTATE_STORAGE="${TFSTATE_STORAGE:-sttfstatebadisazmig001}"
TFSTATE_CONTAINER="${TFSTATE_CONTAINER:-tfstate}"

TAGS=(
  project=azure-legacy-migration-lab
  environment=dev
  owner=badis
  managed_by=azure-cli
  purpose=tfstate
)

echo "Using Terraform state backend:"
echo "  Resource Group : ${TFSTATE_RG}"
echo "  Location       : ${TFSTATE_LOCATION}"
echo "  Storage Account: ${TFSTATE_STORAGE}"
echo "  Container      : ${TFSTATE_CONTAINER}"
echo

echo "Checking Azure login..."
az account show --output table >/dev/null

echo "Creating or updating backend Resource Group..."
az group create \
  --name "${TFSTATE_RG}" \
  --location "${TFSTATE_LOCATION}" \
  --tags "${TAGS[@]}" \
  --output table

echo "Creating backend Storage Account if needed..."
if az storage account show \
  --name "${TFSTATE_STORAGE}" \
  --resource-group "${TFSTATE_RG}" \
  >/dev/null 2>&1; then
  echo "Storage Account already exists: ${TFSTATE_STORAGE}"
else
  az storage account create \
    --name "${TFSTATE_STORAGE}" \
    --resource-group "${TFSTATE_RG}" \
    --location "${TFSTATE_LOCATION}" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --output table
fi

echo "Creating blob container if needed..."
az storage container create \
  --name "${TFSTATE_CONTAINER}" \
  --account-name "${TFSTATE_STORAGE}" \
  --auth-mode login \
  --output table

echo "Assigning Storage Blob Data Contributor to signed-in user..."
SIGNED_IN_USER_ID="$(az ad signed-in-user show --query id -o tsv)"

STORAGE_SCOPE="$(az storage account show \
  --name "${TFSTATE_STORAGE}" \
  --resource-group "${TFSTATE_RG}" \
  --query id \
  -o tsv)"

if az role assignment list \
  --assignee "${SIGNED_IN_USER_ID}" \
  --role "Storage Blob Data Contributor" \
  --scope "${STORAGE_SCOPE}" \
  --query "[].id" \
  -o tsv | grep -q .; then
  echo "Role assignment already exists."
else
  az role assignment create \
    --assignee "${SIGNED_IN_USER_ID}" \
    --role "Storage Blob Data Contributor" \
    --scope "${STORAGE_SCOPE}" \
    --output table
fi

echo
echo "Backend bootstrap complete."
echo "If this is a new setup, run:"
echo "  cd infra/terraform"
echo "  terraform init -migrate-state"
