# =============================================================================
# OpenClaw GCP Deployment - Variables
# =============================================================================
# Configurable parameters for deploying OpenClaw on Google Cloud Platform
# with Tailscale for secure remote access.
# =============================================================================

# -----------------------------------------------------------------------------
# GCP Project Configuration
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
}

variable "region" {
  description = "The GCP region for regional resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for zonal resources (VM instance)"
  type        = string
  default     = "us-central1-a"
}

# -----------------------------------------------------------------------------
# Compute Engine Configuration
# -----------------------------------------------------------------------------

variable "instance_name" {
  description = "Name of the Compute Engine VM instance"
  type        = string
  default     = "openclaw-gateway"
}

variable "machine_type" {
  description = "Machine type for the VM (e2-small recommended, e2-micro for free tier)"
  type        = string
  default     = "e2-small"

  validation {
    condition     = can(regex("^(e2-micro|e2-small|e2-medium|n1-standard-1|n2-standard-2)$", var.machine_type))
    error_message = "Machine type must be one of: e2-micro, e2-small, e2-medium, n1-standard-1, n2-standard-2."
  }
}

variable "boot_disk_size_gb" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.boot_disk_size_gb >= 10 && var.boot_disk_size_gb <= 500
    error_message = "Boot disk size must be between 10 and 500 GB."
  }
}

variable "boot_disk_type" {
  description = "Type of boot disk (pd-standard, pd-balanced, pd-ssd)"
  type        = string
  default     = "pd-balanced"
}

variable "image_family" {
  description = "OS image family for the VM"
  type        = string
  default     = "debian-12"
}

variable "image_project" {
  description = "Project containing the OS image"
  type        = string
  default     = "debian-cloud"
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "network" {
  description = "VPC network name"
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "VPC subnetwork name (leave empty for default)"
  type        = string
  default     = ""
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to the VM (required for Tailscale initial auth)"
  type        = bool
  default     = true
}

variable "enable_iap_ssh" {
  description = "Enable IAP TCP tunneling for SSH access (recommended)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Tailscale Configuration
# -----------------------------------------------------------------------------

variable "tailscale_auth_key" {
  description = "Tailscale auth key for automatic node registration (generate at https://login.tailscale.com/admin/settings/keys)"
  type        = string
  sensitive   = true
}

variable "tailscale_hostname" {
  description = "Hostname for the Tailscale node"
  type        = string
  default     = "openclaw-gcp"
}

variable "tailscale_advertise_tags" {
  description = "Tailscale ACL tags to advertise (e.g., 'tag:server')"
  type        = list(string)
  default     = []
}

variable "tailscale_serve_mode" {
  description = "Tailscale Serve mode: 'serve' (tailnet-only) or 'funnel' (public)"
  type        = string
  default     = "serve"

  validation {
    condition     = contains(["serve", "funnel", "off"], var.tailscale_serve_mode)
    error_message = "Tailscale serve mode must be one of: serve, funnel, off."
  }
}

# -----------------------------------------------------------------------------
# OpenClaw Configuration
# -----------------------------------------------------------------------------

variable "openclaw_gateway_port" {
  description = "Port for the OpenClaw Gateway WebSocket"
  type        = number
  default     = 18789
}

variable "openclaw_gateway_token" {
  description = "Authentication token for the OpenClaw Gateway (generate with: openssl rand -hex 32)"
  type        = string
  sensitive   = true
}

variable "openclaw_gateway_password" {
  description = "Password for OpenClaw Gateway (required if using Tailscale Funnel)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "anthropic_api_key" {
  description = "Anthropic API key for Claude models"
  type        = string
  sensitive   = true
  default     = ""
}

variable "openai_api_key" {
  description = "OpenAI API key (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

# -----------------------------------------------------------------------------
# Messaging Channel Tokens (Optional)
# -----------------------------------------------------------------------------

variable "telegram_bot_token" {
  description = "Telegram bot token (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "discord_bot_token" {
  description = "Discord bot token (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_bot_token" {
  description = "Slack bot token (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_app_token" {
  description = "Slack app token (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

# -----------------------------------------------------------------------------
# Labels and Tags
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    app         = "openclaw"
    environment = "production"
    managed_by  = "terraform"
  }
}

variable "network_tags" {
  description = "Network tags for the VM instance"
  type        = list(string)
  default     = ["openclaw-gateway"]
}
