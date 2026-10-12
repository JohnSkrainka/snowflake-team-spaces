#!/usr/bin/env bash
# Generates the key pair Terraform uses to log in as TERRAFORM_SVC.
# Usage: ./bootstrap/make_key.sh [key_dir]   (default: ~/.ssh)
set -euo pipefail

KEY_DIR="${1:-$HOME/.ssh}"
PRIV="$KEY_DIR/snowflake_tf_key.p8"
PUB="$KEY_DIR/snowflake_tf_key.pub"

if [[ -e "$PRIV" ]]; then
  echo "$PRIV already exists; not overwriting." >&2
else
  mkdir -p "$KEY_DIR"
  # Unencrypted PKCS#8, the format the provider reads from SNOWFLAKE_PRIVATE_KEY.
  openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out "$PRIV" -nocrypt
  chmod 600 "$PRIV"
  openssl rsa -in "$PRIV" -pubout -out "$PUB" 2>/dev/null
fi

echo
echo "Public key for bootstrap/terraform_user.sql (RSA_PUBLIC_KEY):"
echo
grep -v "PUBLIC KEY" "$PUB" | tr -d '\n'
echo
