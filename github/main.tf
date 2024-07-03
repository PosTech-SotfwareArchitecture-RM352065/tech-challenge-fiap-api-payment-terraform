resource "github_actions_organization_variable" "sanduba_payment_url" {
  variable_name = "APP_COSTUMER_URL"
  visibility    = "all"
  value         = var.sanduba_payment_url
}