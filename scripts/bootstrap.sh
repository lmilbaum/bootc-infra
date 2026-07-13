#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <public-ip> <private-key>"
    exit 1
fi

HOST="$1"
KEY="$2"

BOOTC_IMAGE="${BOOTC_IMAGE:-ghcr.io/lmilbaum/bootc-poc:1.0.0}"

SSH_OPTIONS=(
    -i "$KEY"
    -o BatchMode=yes
    -o ConnectTimeout=5
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
)

ssh_fedora() {
    ssh "${SSH_OPTIONS[@]}" fedora@"$HOST" "$@"
}

ssh_root() {
    ssh "${SSH_OPTIONS[@]}" root@"$HOST" "$@"
}

echo "==> Waiting for cloud-init..."

ssh_fedora "sudo cloud-init status --wait"

echo "==> Preparing root SSH access..."

ssh_fedora '
sudo install -d -m700 /root/.ssh
sudo cp /home/fedora/.ssh/authorized_keys /root/.ssh/authorized_keys
sudo chmod 600 /root/.ssh/authorized_keys
'

if [[ -n "${GH_USERNAME:-}" && -n "${GH_PAT:-}" ]]; then
    GH_USERNAME_Q=$(printf '%q' "$GH_USERNAME")

    echo "==> Logging into GHCR..."

    printf '%s\n' "$GH_PAT" | ssh_fedora "sudo podman login ghcr.io -u ${GH_USERNAME_Q} --password-stdin"
fi

echo "==> Pulling bootc image..."

ssh_fedora "
sudo podman pull ${BOOTC_IMAGE}
"

echo "==> Converting system to bootc..."

ssh_fedora "
sudo podman run --rm \
  --privileged \
  --pid=host \
  --ipc=host \
  --security-opt label=type:unconfined_t \
  -v /:/target \
  -v /dev:/dev \
  -v /var/lib/containers:/var/lib/containers \
  ${BOOTC_IMAGE} \
  bootc install to-existing-root \
    --acknowledge-destructive \
    --cleanup \
    --root-ssh-authorized-keys /target/root/.ssh/authorized_keys
"

echo "==> Rebooting..."

ssh_fedora "sudo systemctl reboot" || true

echo "==> Waiting for SSH to go away..."

while ssh_fedora true >/dev/null 2>&1; do
    sleep 2
done

echo "==> Waiting for instance to return..."

until ssh_root true >/dev/null 2>&1; do
    sleep 5
done

echo "==> Waiting for boot to settle..."

sleep 10

echo "==> Verifying bootc deployment..."

ssh_root "
bootc status
"

echo
echo "✅ Conversion completed successfully."
