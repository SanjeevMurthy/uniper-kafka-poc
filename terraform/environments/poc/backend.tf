terraform {
  backend "azurerm" {
    # Concrete values supplied via `-backend-config=...` from CI:
    #   resource_group_name  = vars.TF_STATE_RG       (e.g. "tfstate-rg")
    #   storage_account_name = vars.TF_STATE_SA       (e.g. "tfstateuniperpocXXXXXX")
    #   container_name       = vars.TF_STATE_CONTAINER (e.g. "tfstate")
    #   key                  = "poc.tfstate"
    #
    # Locally:
    #   terraform init \
    #     -backend-config="resource_group_name=tfstate-rg" \
    #     -backend-config="storage_account_name=$(terraform -chdir=../../bootstrap output -raw state_storage_account_name)" \
    #     -backend-config="container_name=tfstate" \
    #     -backend-config="key=poc.tfstate" \
    #     -backend-config="use_azuread_auth=true"
    use_azuread_auth = true
    use_oidc         = true
  }
}
