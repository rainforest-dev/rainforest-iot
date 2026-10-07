#!/bin/bash
set -u

TERRAFORM_VERSION=1.5.7
LOG=/var/log/cloud-setup.log

step() {
  local name=$1
  shift
  "$@" >>"$LOG" 2>&1
  local rc=$?
  echo "$(date -u +%FT%TZ) step=${name} exit=${rc}" >>"$LOG"
  return "$rc"
}

case "$(uname -m)" in
  aarch64 | arm64) arch=arm64 ;;
  *) arch=amd64 ;;
esac
zip=/tmp/terraform.zip

step terraform-download curl -fsSLo "$zip" \
  "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${arch}.zip" &&
  step terraform-install python3 -c "import zipfile, os; zipfile.ZipFile('$zip').extract('terraform', '/usr/local/bin'); os.chmod('/usr/local/bin/terraform', 0o755)"
step terraform-version terraform version

exit 0
