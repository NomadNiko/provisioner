#!/bin/bash

# Parse arguments
while getopts "n:d:" opt; do
  case $opt in
    n) APP_NAME="$OPTARG" ;;
    d) APP_DESCRIPTION="$OPTARG" ;;
  esac
done

# Load .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

cd /var/www/
npx -y create-next-app@latest "$APP_NAME" --ts --tailwind --eslint --app --src-dir --yes
cd /var/www/"$APP_NAME"
git init
git add . && git commit -m "build: initial commit"
git branch -m master main
gh repo create "$APP_NAME" --public --source=. --remote=origin --push
npm install
APP_PORT=$(for port in {27032..65535}; do ss -tuln | grep -q ":$port " || { echo $port; break; }; done)
UNIQUE_SESSION_UUID=$(cat /proc/sys/kernel/random/uuid)
cat > .env << EOF
APP_NAME=$APP_NAME
PORT=$APP_PORT
EOF
npm run build
PORT=$APP_PORT pm2 start npm --name "$APP_NAME" -- run start
sudo cp /etc/nginx/base.config /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
sudo sed -i "s/{appName}/$APP_NAME/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
sudo sed -i "s/{appPort}/$APP_PORT/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
sudo sed -i "s/{SERVER_PUBLIC_IP}/$SERVER_PUBLIC_IP/g" /etc/nginx/sites-enabled/"$APP_NAME".$DEFAULT_DOMAIN
sudo nginx -t && sudo systemctl restart nginx
curl -X POST https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records -H "Authorization: Bearer $CLOUDFLARE_API_KEY" -H "Content-Type: application/json" -d "{\"type\": \"A\", \"name\": \"$APP_NAME.$DEFAULT_DOMAIN\", \"content\": \"$SERVER_PUBLIC_IP\", \"ttl\": 0, \"proxied\": false}"
echo "Waiting 30 seconds for DNS propagation..."
sleep 30
sudo certbot --nginx -d "$APP_NAME".$DEFAULT_DOMAIN --account $CERTBOT_ACCOUNT_ID
sudo nginx -t && sudo systemctl restart nginx
claude -p "Please configure this base site to be a landing page for $APP_NAME an $APP_DESCRIPTION, perform a npm run build and clear any errors before calling this complete" --session-id "$UNIQUE_SESSION_UUID" --dangerously-skip-permissions --output-format=json
pm2 stop $APP_NAME && npm run build && pm2 start $APP_NAME
git add . && git commit -m "build: post claude one shot" && git push
