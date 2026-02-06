# Security Guide

This document outlines security best practices for deploying OpenClaw on Google Cloud Platform.

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Security Layers                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Layer 1: Network Security                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  • Gateway bound to loopback (127.0.0.1)                            │   │
│  │  • No public ports exposed                                          │   │
│  │  • Tailscale mesh provides encrypted tunnel                         │   │
│  │  • IAP for SSH access (no SSH exposed to internet)                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Layer 2: Authentication                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  • Gateway token required for all connections                       │   │
│  │  • Tailscale identity headers for mesh access                       │   │
│  │  • Password auth required for Funnel (public) mode                  │   │
│  │  • GCP IAM for infrastructure access                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Layer 3: Authorization                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  • DM pairing required for new senders                              │   │
│  │  • Group mention gating prevents always-on bots                     │   │
│  │  • Per-session sandboxing for non-main sessions                     │   │
│  │  • Tool allowlists/denylists per agent                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Layer 4: Execution Isolation                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  • Docker container isolation                                       │   │
│  │  • Non-root user execution                                          │   │
│  │  • Read-only workspace mounts (optional)                            │   │
│  │  • Shielded VM with Secure Boot                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Pre-Deployment Checklist

### Secrets Management

- [ ] Gateway token generated with `openssl rand -hex 32` (64 characters)
- [ ] Keyring password generated with `openssl rand -hex 16`
- [ ] All API keys stored in `terraform.tfvars` (never committed)
- [ ] `terraform.tfvars` added to `.gitignore`
- [ ] No secrets in startup script (use Terraform variables)

### Network Security

- [ ] `gateway.bind` set to `loopback` (requires Docker host networking)
- [ ] Docker container using `network_mode: "host"` (required for Tailscale Serve)
- [ ] No public firewall rules for port 18789
- [ ] IAP enabled for SSH access
- [ ] Tailscale Serve mode is `serve` (not `funnel`) unless public access required
- [ ] If using Funnel, password auth is configured

### GCP IAM

- [ ] Service account has minimal permissions (only logging and monitoring)
- [ ] No Owner or Editor roles on service account
- [ ] OS Login enabled for identity-based SSH
- [ ] IAP tunnel access granted only to required users

### OpenClaw Configuration

- [ ] DM policy set to `pairing` for all channels
- [ ] Group chats require `@mention` to respond
- [ ] Sandboxing enabled for non-main sessions
- [ ] `logging.redactSensitive` set to `tools`
- [ ] mDNS discovery mode set to `minimal`

## Secret Rotation

### Gateway Token

```bash
# Generate new token
NEW_TOKEN=$(openssl rand -hex 32)

# Update terraform.tfvars
# Then apply
terraform apply -var="openclaw_gateway_token=$NEW_TOKEN"

# Or update directly on VM
ssh openclaw-gateway
sudo sed -i "s/OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=$NEW_TOKEN/" /opt/openclaw/.env
sudo systemctl restart openclaw
```

### Tailscale Auth Key

1. Generate new key at https://login.tailscale.com/admin/settings/keys
2. Update `terraform.tfvars`
3. Recreate VM: `terraform taint google_compute_instance.openclaw && terraform apply`

### API Keys

```bash
# Update on VM
ssh openclaw-gateway
sudo vim /opt/openclaw/.env
# Update the relevant API key
sudo systemctl restart openclaw
```

## Incident Response

### If You Suspect Compromise

1. **Immediate Actions**
   ```bash
   # Stop the gateway
   ssh openclaw-gateway
   sudo systemctl stop openclaw
   ```

2. **Lock Down Access**
   - Revoke Tailscale node: https://login.tailscale.com/admin/machines
   - Rotate gateway token
   - Rotate all API keys

3. **Investigate**
   ```bash
   # Check logs
   sudo cat /var/log/openclaw-startup.log
   docker compose -f /opt/openclaw/docker-compose.yml logs
   
   # Check session history
   ls -la /home/openclaw/.openclaw/agents/*/sessions/
   ```

4. **Restore**
   - Generate new secrets
   - Redeploy with `terraform destroy && terraform apply`

### Audit Logging

Enable GCP Cloud Audit Logs for the project:

```bash
gcloud projects get-iam-policy PROJECT_ID \
    --format=json > policy.json

# Add audit config and apply
gcloud projects set-iam-policy PROJECT_ID policy.json
```

## Network Security Details

### Firewall Rules

| Rule | Source | Ports | Purpose |
|------|--------|-------|---------|
| `allow-iap-ssh` | `35.235.240.0/20` | 22 | IAP SSH tunneling |
| `allow-iap-gateway` | `35.235.240.0/20` | 18789 | IAP Gateway tunneling |
| `allow-egress` | Internal | 80,443,41641 | Outbound traffic |

### Why No Public Firewall Rules?

The gateway should never be directly exposed to the internet because:

1. **Prompt Injection Risk**: Attackers could send malicious messages
2. **Token Brute Force**: Exposed endpoints can be attacked
3. **Information Disclosure**: Error messages may leak info
4. **Resource Exhaustion**: DDoS attacks could drain API credits

### Tailscale Security Model

Tailscale provides:

- **WireGuard Encryption**: All traffic encrypted end-to-end
- **Identity Verification**: Each node has cryptographic identity
- **ACL Support**: Define who can access what
- **Audit Logs**: Track all connection attempts

## Hardening Guide

### VM Hardening

```bash
# Enable automatic security updates
sudo apt-get install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Set up fail2ban
sudo apt-get install fail2ban
sudo systemctl enable fail2ban
```

### Docker Hardening

The provided Dockerfile includes:

- Non-root user execution
- `no-new-privileges` security option
- Resource limits
- Health checks

### Additional Hardening

```hcl
# In main.tf, the shielded VM config is already enabled:
shielded_instance_config {
  enable_secure_boot          = true
  enable_vtpm                 = true
  enable_integrity_monitoring = true
}
```

## Compliance Considerations

### Data Residency

- VM location controlled by `zone` variable
- Session data stored locally on VM
- API calls go to model provider (consider data handling policies)

### Data Retention

```bash
# Set up log rotation
sudo cat > /etc/logrotate.d/openclaw << EOF
/var/log/openclaw-*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

### Backup

```bash
# Backup OpenClaw state
tar -czf openclaw-backup-$(date +%Y%m%d).tar.gz \
    /home/openclaw/.openclaw

# Upload to Cloud Storage
gsutil cp openclaw-backup-*.tar.gz gs://your-backup-bucket/
```

## Security Resources

- [OpenClaw Security Docs](https://docs.clawd.bot/gateway/security)
- [GCP Security Best Practices](https://cloud.google.com/security/best-practices)
- [Tailscale Security](https://tailscale.com/security)
- [Docker Security](https://docs.docker.com/engine/security/)
