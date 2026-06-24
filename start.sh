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

# ── Patch CW agent config with Task ID ───────────────────────────────────────
sed -i "s/{instance_id}/$TASK_ID/g" \
  /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# ── Start CloudWatch Agent (direct binary, no systemctl) ──────────────────────
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent \
  -config /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -pidfile /var/run/amazon-cloudwatch-agent.pid \
  &

echo "CloudWatch agent started (PID $!)"

# ── Start nginx ───────────────────────────────────────────────────────────────
service nginx start
echo "nginx started."

# ── Start Puma (foreground, PID 1) ───────────────────────────────────────────
exec bundle exec puma -C config/puma.rb