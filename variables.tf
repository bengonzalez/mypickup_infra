variable "project_name" {
  description = "Short name used as a prefix for all resource names."
  type        = string
  default     = "mypickup"
}

variable "environment" {
  description = "Environment suffix used in resource names (e.g. dev, prod)."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "min_replicas" {
  description = "Minimum number of Container App replicas. 0 allows scale-to-zero when idle."
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Maximum number of Container App replicas."
  type        = number
  default     = 1
}

variable "container_cpu" {
  description = "CPU cores allocated to the container (must be a valid Container Apps Consumption combination, e.g. 0.25 with 0.5Gi memory)."
  type        = number
  default     = 0.25
}

variable "container_memory" {
  description = "Memory allocated to the container (must pair with container_cpu, e.g. 0.5Gi with 0.25 CPU)."
  type        = string
  default     = "0.5Gi"
}

variable "container_image" {
  description = "Full image reference (registry/repo:tag) to deploy. Defaults to a public placeholder so the first `terraform apply` succeeds before any image has been pushed to the ACR created here. GitHub Actions updates the running image afterwards via `az containerapp update` (Terraform ignores further drift on this field)."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "django_secret_key" {
  description = "Value for the DJANGO_SECRET_KEY environment variable. Required, no default."
  type        = string
  sensitive   = true
}

variable "django_debug" {
  description = "Value for the DJANGO_DEBUG environment variable."
  type        = string
  default     = "False"
}

variable "email_user" {
  description = "Gmail SMTP username for Django password-reset emails (EMAIL_USER). Leave blank to disable."
  type        = string
  default     = ""
  sensitive   = true
}

variable "email_pass" {
  description = "Gmail SMTP app password for Django password-reset emails (EMAIL_PASS). Leave blank to disable."
  type        = string
  default     = ""
  sensitive   = true
}

variable "media_share_quota_gb" {
  description = "Quota (in GB) for the Azure Files share used to persist Django media uploads."
  type        = number
  default     = 5
}

variable "postgres_admin_login" {
  description = "Administrator login for the PostgreSQL Flexible Server."
  type        = string
  default     = "mypickupadmin"
}

variable "postgres_db_name" {
  description = "Name of the application database on the PostgreSQL Flexible Server."
  type        = string
  default     = "mypickup"
}

variable "postgres_sku_name" {
  description = "SKU for the PostgreSQL Flexible Server, in tier_family_cores form (e.g. B_Standard_B2s). B_Standard_B1ms failed with SkuNotAvailable (no real-time capacity) in eastus2 despite being listed in the region's SKU catalog."
  type        = string
  default     = "B_Standard_B2s"
}

variable "postgres_storage_mb" {
  description = "Storage (in MB) provisioned for the PostgreSQL Flexible Server."
  type        = number
  default     = 32768
}

variable "postgres_version" {
  description = "PostgreSQL major version for the Flexible Server."
  type        = string
  default     = "16"
}

variable "postgres_location" {
  description = "Azure region for the PostgreSQL Flexible Server. Separate from var.location because Flexible Server provisioning is restricted for this subscription in eastus."
  type        = string
  default     = "eastus2"
}
