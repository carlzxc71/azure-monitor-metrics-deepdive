variable "subscription_id" {
  description = "Subscription ID"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, test, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
}

variable "location_short" {
  description = "Short abbreviation for the Azure region (e.g. sc for swedencentral)"
  type        = string
}

