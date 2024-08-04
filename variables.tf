variable "environment" {
  type      = string
  sensitive = false
  default   = ""
}

variable "location" {
  type      = string
  sensitive = false
  default   = ""
}

variable "mercadopago_authentication_token" {
  sensitive = true
  default   = ""
}

variable "mercadopago_user_id" {
  sensitive = true
  default   = ""
}

variable "mercadopago_cashier_id" {
  sensitive = true
  default   = ""
}

