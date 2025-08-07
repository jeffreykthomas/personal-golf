# Deployment Checklist for golf-tip.org

## Prerequisites

- [ ] Install Fly CLI: `brew install flyctl`
- [ ] Create Fly.io account: https://fly.io/app/sign-up
- [ ] Have Cloudflare account ready

## Initial Setup (One Time)

### 1. Deploy to Fly.io

```bash
# From project root
cd /Users/jeffreythomas/Documents/personal-golf

# Login to Fly
fly auth login

# Launch app
fly launch --name golf-tip-app
# Answer: NO to PostgreSQL, YES to deploy

# Set Rails master key
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key)

# Get your app's IP address
fly ips list
# If no IPv4 shown, allocate one:
fly ips allocate-v4
```

### 2. Configure Cloudflare

1. Add golf-tip.org to Cloudflare
2. Update nameservers at your domain registrar
3. Add DNS records:
   - A record: @ → [Your Fly IPv4] (Proxied)
   - CNAME: www → golf-tip.org (Proxied)
4. **IMPORTANT**: Set SSL/TLS to "Full (strict)"

### 3. Add Domain to Fly

```bash
fly certs add golf-tip.org
fly certs add www.golf-tip.org

# Verify certificates (may take a few minutes)
fly certs list
```

## Regular Deployment

### Deploy Changes

```bash
# Commit your changes
git add .
git commit -m "Your changes"

# Deploy to Fly
fly deploy

# Monitor logs
fly logs -f
```

### Useful Commands

```bash
# Check app status
fly status

# SSH into app
fly ssh console

# Rails console
fly ssh console -C "bin/rails console"

# Database backup (manual)
fly ssh console -C "cp /data/*.sqlite3 /tmp/ && tar -czf /tmp/backup.tar.gz /tmp/*.sqlite3"
fly ssh console -C "cat /tmp/backup.tar.gz" > backup-$(date +%Y%m%d).tar.gz

# View secrets (names only)
fly secrets list

# Update a secret
fly secrets set SECRET_NAME=value

# Scale app
fly scale vm shared-cpu-1x --memory 256  # Free tier
fly scale vm shared-cpu-1x --memory 512  # Paid tier
```

## Monitoring

- Fly Dashboard: https://fly.io/apps/golf-tip-app
- Metrics: https://fly.io/apps/golf-tip-app/metrics
- Your site: https://golf-tip.org

## Troubleshooting

### If deployment fails:

1. Check logs: `fly logs`
2. Check build logs: `fly deploy --verbose`
3. SSH and check: `fly ssh console`

### If site shows Cloudflare error:

1. Verify DNS propagation: https://www.whatsmydns.net/#A/golf-tip.org
2. Check Fly certificate status: `fly certs list`
3. Ensure Cloudflare SSL is set to "Full (strict)"

### Database issues:

- Database is stored at `/data/` in the container
- Fly automatically backs up volumes
- Manual backup command included above

## Notes

- Free tier includes 3 shared VMs
- SQLite works great for this app size
- Fly handles SSL between their edge and your app
- Cloudflare provides additional DDoS protection and CDN

## Support

- Fly.io docs: https://fly.io/docs/
- Fly community: https://community.fly.io/
- Status page: https://status.flyio.net/
