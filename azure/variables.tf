variable "environment" {
  type      = string
  sensitive = false
}

variable "location" {
  type      = string
  sensitive = false
}

variable "main_resource_group" {
  type      = string
  sensitive = false
  default   = ""
}

variable "main_resource_group_location" {
  type      = string
  sensitive = false
  default   = ""
}

variable "mercadopago_authentication_token" {
  sensitive = true
}

variable "mercadopago_user_id" {
  sensitive = true
}

variable "mercadopago_cashier_id" {
  sensitive = true
}
