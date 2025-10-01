variable "appgw_sku" {
  type    = string
  default = "WAF_v2"
  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.appgw_sku)
    error_message = "appgw_sku must be either 'Standard_v2' or 'WAF_v2'"
  }
}

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID where resources will be created"
  default     = "331f9ae3-8ff4-4fea-918e-86d7e4290a58"
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a valid UUID format"
  }
}
