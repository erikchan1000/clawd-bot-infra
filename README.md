# OpenClaw GCP Deployment

Deploy [OpenClaw](https://github.com/openclaw/openclaw) - your personal AI assistant - on Google Cloud Platform with secure remote access via Tailscale.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Your Devices                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Laptop    │  │   Phone     │  │  macOS App  │  │   Tablet    │        │
│  │ (Tailscale) │  │ (Tailscale) │  │ (Tailscale) │  │ (Tailscale) │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
└─────────┼────────────────┼────────────────┼────────────────┼────────────────┘
          │                │                │                │
          └────────────────┴────────┬───────┴────────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │      Tailscale Mesh Network   │
                    │       (WireGuard Encrypted)   │
                    └───────────────┬───────────────┘
                                    │
┌───────────────────────────────────▼───────────────────────────────────────┐
│                        Google Cloud Platform                               │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                    Compute Engine VM                                 │  │
│  │  ┌─────────────────┐  ┌─────────────────────────────────────────┐  │  │
│  │  │   Tailscale     │  │           Docker Container              │  │  │
│  │  │    Daemon       │──│  ┌─────────────────────────────────┐   │  │  │
│  │  │                 │  │  │      OpenClaw Gateway           │   │  │  │
│  │  │ Serve/Funnel    │  │  │    ws://127.0.0.1:18789         │   │  │  │
│  │  └─────────────────┘  │  └─────────────────────────────────┘   │  │  │
│  │                       └─────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                    │                                       │
│                                    ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                    Messaging Channels (Outbound)                    │  │
│  │     Telegram  │  WhatsApp  │  Discord  │  Slack  │  Signal          │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
```

## Features

- **Secure by Default**: Gateway bound to loopback, accessed via Tailscale mesh
- **Zero-Trust Networking**: WireGuard encryption with identity-based access
- **Infrastructure as Code**: Fully automated with Terraform
- **Persistent State**: Survives restarts and updates
- **Multi-Channel Support**: Telegram, WhatsApp, Discord, Slack, Signal, and more
- **Cost-Effective**: Runs on e2-small (~$12/month) or free-tier e2-micro

## Prerequisites

- [Google Cloud Account](https://cloud.google.com/) with billing enabled
- [Tailscale Account](https://tailscale.com/) (free for personal use)
- [Terraform](https://terraform.io/) >= 1.0.0
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- API key for your AI model provider (Anthropic recommended)

## Quick Start

### 1. Clone and Configure

```bash
# Clone this repository
git clone https://github.com/your-org/openclaw-gcp.git
cd openclaw-gcp/terraform

# Copy and edit the variables file
cp terraform.tfvars.example terraform.tfvars
```

### 2. Generate Required Secrets

```bash
# Generate OpenClaw gateway token
openssl rand -hex 32
# Output: your-64-character-token

# Generate keyring password
openssl rand -hex 16
```

### 3. Get a Tailscale Auth Key

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
2. Click "Generate auth key"
3. Enable "Reusable" if you plan to redeploy
4. Copy the key (starts with `tskey-auth-`)

### 4. Configure terraform.tfvars

Edit `terraform.tfvars` with your values:

```hcl
project_id = "your-gcp-project-id"

# Tailscale
tailscale_auth_key = "tskey-auth-xxxxx"
tailscale_hostname = "openclaw-gcp"

# OpenClaw
openclaw_gateway_token = "your-64-char-token"
anthropic_api_key      = "sk-ant-xxxxx"

# Optional: Messaging channels
# telegram_bot_token = "123456789:ABCdef..."
```

### 5. Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy
terraform apply
```

### 6. Access OpenClaw

**Via Tailscale (Recommended):**

1. Install Tailscale on your device
2. Access: `https://openclaw-gcp.<your-tailnet>.ts.net/`

**Via IAP Tunnel (Alternative):**

```bash
# Create tunnel
gcloud compute start-iap-tunnel openclaw-gateway 18789 \
    --local-host-port=localhost:18789 \
    --zone=us-central1-a

# Access in browser
open http://localhost:18789/
```

## Configuration Reference

### Terraform Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `project_id` | GCP project ID | - | Yes |
| `region` | GCP region | `us-central1` | No |
| `zone` | GCP zone | `us-central1-a` | No |
| `machine_type` | VM machine type | `e2-small` | No |
| `tailscale_auth_key` | Tailscale auth key | - | Yes |
| `tailscale_hostname` | Tailscale node name | `openclaw-gcp` | No |
| `tailscale_serve_mode` | `serve`, `funnel`, or `off` | `serve` | No |
| `openclaw_gateway_token` | Gateway auth token | - | Yes |
| `anthropic_api_key` | Anthropic API key | - | Yes* |

*At least one model provider API key is required.

### Tailscale Serve Modes

| Mode | Access | Use Case |
|------|--------|----------|
| `serve` | Tailnet only | Personal use (recommended) |
| `funnel` | Public internet | Webhooks, public access |
| `off` | IAP tunnel only | Maximum security |

### Machine Types

| Type | Specs | Monthly Cost | Notes |
|------|-------|--------------|-------|
| `e2-micro` | 2 shared vCPU, 1GB RAM | Free tier eligible | May OOM under load |
| `e2-small` | 2 vCPU, 2GB RAM | ~$12 | Recommended |
| `e2-medium` | 2 vCPU, 4GB RAM | ~$24 | For heavy use |

## Security Checklist

Before deploying to production, ensure:

- [ ] Gateway token is a strong random value (64+ chars)
- [ ] API keys are not committed to version control
- [ ] `tailscale_serve_mode` is `serve` (not `funnel`) unless you need public access
- [ ] If using Funnel, `openclaw_gateway_password` is set
- [ ] DM policies are set to `pairing` for all channels
- [ ] Group chats require `@mention` to respond
- [ ] Sandboxing is enabled for non-main sessions
- [ ] `terraform.tfvars` is in `.gitignore`

## Maintenance

### SSH into the VM

```bash
gcloud compute ssh openclaw-gateway --zone=us-central1-a --tunnel-through-iap
```

### View Logs

```bash
# On the VM
docker compose -f /opt/openclaw/docker-compose.yml logs -f

# Startup log
cat /var/log/openclaw-startup.log
```

### Update OpenClaw

```bash
# On the VM
cd /opt/openclaw
git pull
docker compose build
docker compose up -d
```

### Restart Gateway

```bash
# On the VM
sudo systemctl restart openclaw
```

### Check Tailscale Status

```bash
# On the VM
tailscale status
```

## Troubleshooting

### VM won't start

Check startup script logs:
```bash
gcloud compute instances get-serial-port-output openclaw-gateway --zone=us-central1-a
```

### Can't connect via Tailscale

1. Verify Tailscale is running: `tailscale status`
2. Check if Serve is configured: `tailscale serve status`
3. Verify your device is on the same tailnet

### Gateway not responding

```bash
# Check Docker container status
docker compose -f /opt/openclaw/docker-compose.yml ps

# Check container logs
docker compose -f /opt/openclaw/docker-compose.yml logs openclaw-gateway
```

### IAP tunnel fails

1. Ensure IAP API is enabled
2. Verify you have `roles/iap.tunnelResourceAccessor` permission
3. Check firewall rules allow IAP range: `35.235.240.0/20`

## Destroy Infrastructure

To tear down all resources:

```bash
terraform destroy
```

**Warning**: This will delete all data. Back up `~/.openclaw` first if needed.

## Cost Optimization

- Use `e2-micro` for light usage (free tier eligible)
- Use preemptible VMs for non-critical deployments (80% cheaper)
- Set up budget alerts in GCP Console
- Consider committed use discounts for long-term deployments

## Alternative Access Methods

### Pure GCP (No Tailscale)

If you prefer not to use Tailscale:

1. Set `tailscale_serve_mode = "off"` in terraform.tfvars
2. Use IAP TCP tunneling for access:
   ```bash
   gcloud compute start-iap-tunnel openclaw-gateway 18789 \
       --local-host-port=localhost:18789 \
       --zone=us-central1-a
   ```

### Direct Port Exposure (Not Recommended)

For testing only - not recommended for production:

1. Add a firewall rule to allow port 18789
2. Set `gateway.bind: "lan"` in openclaw.json
3. Ensure a strong gateway token is configured

## Contributing

Contributions are welcome! Please read the [OpenClaw contributing guidelines](https://github.com/openclaw/openclaw/blob/main/CONTRIBUTING.md).

## License

This deployment configuration is provided under the MIT License.

OpenClaw itself is licensed under [MIT License](https://github.com/openclaw/openclaw/blob/main/LICENSE).

## Resources

- [OpenClaw Documentation](https://docs.clawd.bot/)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [GCP Compute Engine Docs](https://cloud.google.com/compute/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
