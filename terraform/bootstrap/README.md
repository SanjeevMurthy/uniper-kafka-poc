# Stack: `bootstrap`

Provisions the prerequisites for the rest of the repo:

1. **Terraform state backend** — Azure resource group + storage account
   (AAD-only, versioned, `prevent_destroy`) + blob container.
2. **OIDC identity for GitHub Actions** — Azure AD app registration with
   two federated credentials (no client secret) + a service principal.
3. **RBAC** — subscription Contributor + state SA Storage Blob Data Owner
   + POC RG-scoped User Access Administrator.

This stack runs **rarely**. The very first apply happens locally with a
human's `az login`; subsequent applies run from the `bootstrap.yml`
workflow using OIDC just like the POC stack.

See the repo-root [`SETUP.md`](../../SETUP.md) for end-to-end setup.

---

## Resources created

| Resource | Purpose |
|----------|---------|
| `azurerm_resource_group.state` | Holds the state SA; outlives the POC RG |
| `azurerm_storage_account.state` | Versioned, AAD-only, `prevent_destroy = true` |
| `azurerm_storage_container.state` | One blob per stack |
| `azuread_application.gh` | The identity GitHub Actions impersonates |
| `azuread_service_principal.gh` | Concrete principal for RBAC |
| `azuread_application_federated_identity_credential.gh` × 2 | bootstrap / poc |
| `azurerm_role_assignment.sp_subscription_contributor` | Lets the SP create POC resources |
| `azurerm_role_assignment.sp_state_blob_owner` | Lets the SP read/write state |
| `azurerm_role_assignment.sp_poc_rg_uaa` | Lets the POC stack create role assignments inside its RG |

## First-run procedure (local, one-time, ~15 min)

```bash
# 1. Sign in to Azure as a subscription Owner.
az login --tenant <your-tenant-id>
az account set --subscription <your-subscription-id>

# 2. (You should already be in this directory.)
cd terraform/bootstrap

# 3. Copy the example tfvars and fill in real values.
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars

# 4. Confirm backend.tf is COMMENTED OUT (it is by default).
grep -E '^[^#]' backend.tf | grep -q backend && echo "ERROR: uncomment after first apply, not before" || echo "OK: backend commented out"

# 5. Initialise with local backend and apply.
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 6. Capture outputs and configure GitHub.
export STATE_SA=$(terraform output -raw state_storage_account_name)
export CLIENT_ID=$(terraform output -raw github_actions_client_id)
export TENANT_ID=$(terraform output -raw azure_tenant_id)
export SUB_ID=$(terraform output -raw azure_subscription_id)

gh variable set AZURE_TENANT_ID       --body "$TENANT_ID"
gh variable set AZURE_SUBSCRIPTION_ID --body "$SUB_ID"
gh variable set AZURE_CLIENT_ID       --body "$CLIENT_ID"
gh variable set AZURE_REGION          --body "westeurope"
gh variable set TF_STATE_RG           --body "tfstate-rg"
gh variable set TF_STATE_SA           --body "$STATE_SA"
gh variable set TF_STATE_CONTAINER    --body "tfstate"
gh variable set TF_VERSION            --body "1.9.5"
gh variable set CONFLUENT_REGION      --body "westeurope"
gh variable set PROJECT_NAME          --body "uniper-poc"

gh secret set CONFLUENT_CLOUD_API_KEY    --env poc       --body "<api-key>"
gh secret set CONFLUENT_CLOUD_API_SECRET --env poc       --body "<api-secret>"
gh secret set CONFLUENT_CLOUD_API_KEY    --env bootstrap --body "<api-key>"
gh secret set CONFLUENT_CLOUD_API_SECRET --env bootstrap --body "<api-secret>"

# 7. Uncomment the backend block in backend.tf, then migrate state.
$EDITOR backend.tf  # remove the leading "# " from the terraform/backend lines

terraform init -migrate-state \
  -backend-config="resource_group_name=tfstate-rg" \
  -backend-config="storage_account_name=$STATE_SA" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=bootstrap.tfstate" \
  -backend-config="use_azuread_auth=true"

# 8. Verify: should show no changes.
terraform plan

# 9. Remove the local state file (it's now in the SA).
rm -f terraform.tfstate terraform.tfstate.backup

# 10. Commit and push.
cd ../..
git add terraform/bootstrap/backend.tf
git commit -m "feat(bootstrap): migrate state to remote backend"
git push
```

After step 10, all future bootstrap changes go through the
`.github/workflows/bootstrap.yml` workflow.

## Subsequent runs (CI, every time after the first)

Use the `bootstrap` workflow in the Actions tab. Action `plan` to preview,
`apply` (with confirmation `BOOTSTRAP`) to execute.

## Destroying the bootstrap stack

> [!CAUTION]
> Only do this if you are completely retiring the repo. Destroying bootstrap
> deletes the AD app and the state SA, which makes future applies of the
> POC stack impossible without reimporting every resource.

1. First confirm the POC stack is destroyed (`terraform/environments/poc` shows no resources in state).
2. Comment out the `lifecycle { prevent_destroy = true }` on `azurerm_storage_account.state`.
3. `terraform init -migrate-state -backend=false` to bring state back local.
4. `terraform destroy`.
5. Hard-delete soft-deleted blobs and AD apps within their 30-day windows if you need a zero footprint.

## Gotchas

- **First run requires subscription Owner** (Contributor + User Access Administrator).
  Tenant-admin consent may also be needed for the AD app creation if your
  tenant restricts that permission.
- **Storage account name is globally unique.** The `random_string` suffix
  prevents collisions but the first 18 chars must still be policy-compliant
  (lowercase alphanumeric only).
- **State migration is one-way safe** — `terraform init -migrate-state`
  uploads the local state to the remote backend. Keep `terraform.tfstate`
  on disk only until step 9.
- **`prevent_destroy` is set on the state SA**, not the RG. If you need to
  rename or relocate the SA, plan a controlled migration (out of scope here).
