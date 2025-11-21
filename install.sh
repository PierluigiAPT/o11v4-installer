#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/adilem/o11v4"
APP_BASE="/home/o11"
APP_DIR="${APP_BASE}/o11v4"
SERVICE_FILE="/etc/systemd/system/o11v4.service"
BINARY_PATH="${APP_DIR}/o11_v4"
O11_PORT="${O11_PORT:-8484}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

apt-get update -y
apt-get upgrade -y
apt-get install -y curl ca-certificates git python3 python3-pip

if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
  apt-get install -y nodejs
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm missing"
  exit 1
fi

if ! command -v pm2 >/dev/null 2>&1; then
  npm install -g pm2
fi

mkdir -p "${APP_BASE}"

if [[ ! -d "${APP_DIR}/.git" ]]; then
  git clone "${REPO_URL}" "${APP_DIR}"
else
  cd "${APP_DIR}"
  git fetch origin || true
  git pull origin main || git pull origin master || true
fi

cd "${APP_DIR}"

if [[ -f package.json ]]; then
  npm install
else
  npm install -g express
fi

if [[ -f "${APP_DIR}/server.js" ]]; then
  pm2 start server.js --name licserver --silent || true
  pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
  pm2 save || true
fi

if [[ -f "${BINARY_PATH}" ]]; then
  chmod +x "${BINARY_PATH}"
fi

cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=O11 V4 Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${APP_DIR}
ExecStart=${BINARY_PATH} -p ${O11_PORT}
Restart=always
RestartSec=5
StandardOutput=file:${APP_DIR}/o11v4.log
StandardError=file:${APP_DIR}/o11v4.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable o11v4.service
systemctl restart o11v4.service

if ! grep -q "lic.cryptolive.one" /etc/hosts; then
  echo "127.0.0.1 lic.cryptolive.one" >> /etc/hosts
fi

if ! grep -q "lic.bitmaster.cc" /etc/hosts; then
  echo "127.0.0.1 lic.bitmaster.cc" >> /etc/hosts
fi

pip3 install --upgrade curl_cffi pyplayready dnspython requests_toolbelt PySocks xmltodict pytz

echo "Done"
