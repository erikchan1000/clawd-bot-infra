# =============================================================================
# OpenClaw GCP Deployment - Main Configuration
# =============================================================================
# Deploys OpenClaw on Google Cloud Platform with:
# - Compute Engine VM with Docker
# - Tailscale for secure remote access
# - Minimal firewall rules (SSH only for initial setup)
# - Service account with least-privilege IAM
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# -----------------------------------------------------------------------------
# Enable Required APIs
# -----------------------------------------------------------------------------
# NOTE: APIs must be enabled manually before running Terraform.
# Run these commands first:
#   gcloud services enable compute.googleapis.com
#   gcloud services enable iam.googleapis.com
#   gcloud services enable iap.googleapis.com
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Service Account
# -----------------------------------------------------------------------------

resource "google_service_account" "openclaw" {
  account_id   = "openclaw-gateway"
  display_name = "OpenClaw Gateway Service Account"
  description  = "Service account for OpenClaw Gateway VM with minimal permissions"
}

# Grant minimal permissions - only logging and monitoring
resource "google_project_iam_member" "openclaw_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.openclaw.email}"
}

resource "google_project_iam_member" "openclaw_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.openclaw.email}"
}

# -----------------------------------------------------------------------------
# Firewall Rules
# -----------------------------------------------------------------------------

# Allow SSH from IAP for secure access without public IP exposure
resource "google_compute_firewall" "allow_iap_ssh" {
  count   = var.enable_iap_ssh ? 1 : 0
  name    = "allow-iap-ssh-openclaw"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP's IP range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = var.network_tags

  description = "Allow SSH access via IAP TCP tunneling"

  # APIs must be enabled manually before running Terraform
}

# Allow IAP to forward the OpenClaw gateway port (for IAP TCP tunnel access)
resource "google_compute_firewall" "allow_iap_gateway" {
  count   = var.enable_iap_ssh ? 1 : 0
  name    = "allow-iap-gateway-openclaw"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = [tostring(var.openclaw_gateway_port)]
  }

  # IAP's IP range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = var.network_tags

  description = "Allow OpenClaw Gateway access via IAP TCP tunneling"

  # APIs must be enabled manually before running Terraform
}

# Allow outbound traffic (required for Tailscale, Docker, and messaging channels)
resource "google_compute_firewall" "allow_egress" {
  name      = "allow-egress-openclaw"
  network   = var.network
  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "41641"]  # HTTP, HTTPS, Tailscale
  }

  allow {
    protocol = "udp"
    ports    = ["41641", "3478"]  # Tailscale DERP, STUN
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = var.network_tags

  description = "Allow outbound traffic for Tailscale and messaging channels"

  # APIs must be enabled manually before running Terraform
}

# -----------------------------------------------------------------------------
# Compute Engine Instance
# -----------------------------------------------------------------------------

resource "google_compute_instance" "openclaw" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  tags   = var.network_tags
  labels = var.labels

  boot_disk {
    initialize_params {
      image = "projects/${var.image_project}/global/images/family/${var.image_family}"
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
    }
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork != "" ? var.subnetwork : null

    # Conditionally assign public IP
    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {
        // Ephemeral public IP
      }
    }
  }

  service_account {
    email  = google_service_account.openclaw.email
    scopes = ["cloud-platform"]
  }

  # Startup script - rendered from template
  metadata_startup_script = templatefile("${path.module}/startup.sh", {
    tailscale_auth_key        = var.tailscale_auth_key
    tailscale_hostname        = var.tailscale_hostname
    tailscale_advertise_tags  = join(",", var.tailscale_advertise_tags)
    tailscale_serve_mode      = var.tailscale_serve_mode
    openclaw_gateway_port     = var.openclaw_gateway_port
    openclaw_gateway_token    = var.openclaw_gateway_token
    openclaw_gateway_password = var.openclaw_gateway_password
    anthropic_api_key         = var.anthropic_api_key
    openai_api_key            = var.openai_api_key
    telegram_bot_token        = var.telegram_bot_token
    discord_bot_token         = var.discord_bot_token
    slack_bot_token           = var.slack_bot_token
    slack_app_token           = var.slack_app_token
  })

  # Enable OS Login for IAM-based SSH access
  metadata = {
    enable-oslogin = "TRUE"
  }

  # Allow stopping for updates
  allow_stopping_for_update = true

  # Shielded VM settings for security
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  depends_on = [
    google_compute_firewall.allow_iap_ssh,
    google_compute_firewall.allow_egress,
  ]

  lifecycle {
    ignore_changes = [
      # Ignore changes to metadata_startup_script after initial creation
      # to prevent unnecessary restarts when secrets change
      metadata_startup_script,
    ]
  }
}

# -----------------------------------------------------------------------------
# Static Internal IP (Optional - for stable addressing within VPC)
# -----------------------------------------------------------------------------

resource "google_compute_address" "openclaw_internal" {
  name         = "${var.instance_name}-internal-ip"
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork != "" ? var.subnetwork : "default"
  region       = var.region

  # APIs must be enabled manually before running Terraform
}
