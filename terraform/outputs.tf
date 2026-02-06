# =============================================================================
# OpenClaw GCP Deployment - Outputs
# =============================================================================
# Useful information about the deployed resources
# =============================================================================

# -----------------------------------------------------------------------------
# Instance Information
# -----------------------------------------------------------------------------

output "instance_name" {
  description = "Name of the Compute Engine instance"
  value       = google_compute_instance.openclaw.name
}

output "instance_zone" {
  description = "Zone where the instance is deployed"
  value       = google_compute_instance.openclaw.zone
}

output "instance_id" {
  description = "Instance ID"
  value       = google_compute_instance.openclaw.instance_id
}

output "internal_ip" {
  description = "Internal IP address of the instance"
  value       = google_compute_instance.openclaw.network_interface[0].network_ip
}

output "external_ip" {
  description = "External IP address of the instance (if assigned)"
  value       = var.assign_public_ip ? google_compute_instance.openclaw.network_interface[0].access_config[0].nat_ip : "No public IP assigned"
}

# -----------------------------------------------------------------------------
# Service Account
# -----------------------------------------------------------------------------

output "service_account_email" {
  description = "Email of the service account used by the instance"
  value       = google_service_account.openclaw.email
}

# -----------------------------------------------------------------------------
# Access Instructions
# -----------------------------------------------------------------------------

output "ssh_command" {
  description = "Command to SSH into the instance via IAP"
  value       = "gcloud compute ssh ${google_compute_instance.openclaw.name} --zone=${google_compute_instance.openclaw.zone} --tunnel-through-iap"
}

output "iap_tunnel_command" {
  description = "Command to create an IAP tunnel to the OpenClaw Gateway"
  value       = "gcloud compute start-iap-tunnel ${google_compute_instance.openclaw.name} ${var.openclaw_gateway_port} --local-host-port=localhost:${var.openclaw_gateway_port} --zone=${google_compute_instance.openclaw.zone}"
}

output "tailscale_url" {
  description = "Expected Tailscale URL (after Tailscale is configured)"
  value       = var.tailscale_serve_mode == "funnel" ? "https://${var.tailscale_hostname}.<your-tailnet>.ts.net/" : "https://${var.tailscale_hostname}/ (tailnet-only)"
}

output "local_gateway_url" {
  description = "URL to access the Gateway after creating an IAP tunnel"
  value       = "http://localhost:${var.openclaw_gateway_port}/"
}

# -----------------------------------------------------------------------------
# Deployment Summary
# -----------------------------------------------------------------------------

output "deployment_summary" {
  description = "Summary of the deployment"
  value = <<-EOT

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                     OpenClaw GCP Deployment Complete                         ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║                                                                              ║
    ║  Instance: ${google_compute_instance.openclaw.name}
    ║  Zone: ${google_compute_instance.openclaw.zone}
    ║  Machine Type: ${var.machine_type}
    ║                                                                              ║
    ║  NEXT STEPS:                                                                 ║
    ║                                                                              ║
    ║  1. Wait 3-5 minutes for the startup script to complete                      ║
    ║                                                                              ║
    ║  2. SSH into the instance to verify:                                         ║
    ║     gcloud compute ssh ${google_compute_instance.openclaw.name} --zone=${google_compute_instance.openclaw.zone} --tunnel-through-iap
    ║                                                                              ║
    ║  3. Check OpenClaw status:                                                   ║
    ║     docker compose -f /opt/openclaw/docker-compose.yml logs -f               ║
    ║                                                                              ║
    ║  4. Access via Tailscale (after joining your tailnet):                       ║
    ║     https://${var.tailscale_hostname}.<tailnet>.ts.net/
    ║                                                                              ║
    ║  5. Or create an IAP tunnel for local access:                                ║
    ║     gcloud compute start-iap-tunnel ${google_compute_instance.openclaw.name} ${var.openclaw_gateway_port} \
    ║       --local-host-port=localhost:${var.openclaw_gateway_port} --zone=${google_compute_instance.openclaw.zone}
    ║     Then open: http://localhost:${var.openclaw_gateway_port}/
    ║                                                                              ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

  EOT
}
