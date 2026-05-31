###############################################################################
# IMPORTANT: First run only — leave this block COMMENTED OUT.
#
#   The bootstrap stack creates the storage account that this backend will
#   eventually live in. On the very first apply, there is no SA yet, so
#   Terraform must use a local state file. After apply succeeds:
#
#     1. Uncomment the block below
#     2. terraform init -migrate-state \
#          -backend-config="resource_group_name=tfstate-rg" \
#          -backend-config="storage_account_name=$(terraform output -raw state_storage_account_name)" \
#          -backend-config="container_name=tfstate" \
#          -backend-config="key=bootstrap.tfstate" \
#          -backend-config="use_azuread_auth=true"
#     3. Commit the uncommented backend.tf
#
#   See ../../SETUP.md §2.5 for the full procedure.
#
#   Subsequent runs (whether locally or via CI) read from this backend.
###############################################################################

terraform {
  backend "azurerm" {
    # Concrete values are supplied via `-backend-config=...` to allow the
    # same code to be initialised against state in any subscription.
    #
    # In CI, the bootstrap workflow passes:
    #   resource_group_name  = vars.TF_STATE_RG
    #   storage_account_name = vars.TF_STATE_SA
    #   container_name       = vars.TF_STATE_CONTAINER
    #   key                  = "bootstrap.tfstate"
    use_azuread_auth = true
    use_oidc         = true
  }
}

