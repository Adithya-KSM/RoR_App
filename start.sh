#!/bin/bash
set -e

# ── Resolve ECS Task ID ───────────────────────────────────────────────────────
TASK_META=$(curl -sf "${ECS_CONTAINER_METADATA_URI_V4}/task" || true)
if [ -n "$TASK_META" ]; then
  TASK_ID=$(echo "$TASK_META" | grep -o '"TaskARN":"[^"]*"' | cut -d'/' -f3 | tr -d '"')
else
  TASK_ID=$(hostname)
fi

echo "Task ID: $TASK_ID"

# ── Ensure log dirs exist ─────────────────────────────────────────────────────
mkdir -p /var/log/nginx /app/log
touch /var/log/nginx/access.log \
      /var/log/nginx/error.log \
      /app/log/production.log \
      /app/log/puma.error.log

# ── Patch CW agent config with Task ID ───────────────────────────────────────
sed -i "s/{instance_id}/$TASK_ID/g" \
  /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# ── Start CloudWatch Agent (direct binary, no systemctl) ──────────────────────
# Step 1: Translate JSON config to TOML (agent only accepts TOML)
/opt/aws/amazon-cloudwatch-agent/bin/config-translator \
  --input /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  --output /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.toml \
  --mode ec2 \
  --os linux

# Step 2: Start agent with translated TOML config
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent \
  -config /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.toml \
  -pidfile /var/run/amazon-cloudwatch-agent.pid \
  &

echo "CloudWatch agent started (PID $!)"

# ── Start nginx ───────────────────────────────────────────────────────────────
service nginx start
echo "nginx started."

# ── Start Puma (foreground, PID 1) ───────────────────────────────────────────
exec bundle exec puma -C config/puma.rb