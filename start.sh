#!/bin/bash

# Load Node so we have access to yarn and pm2
source ~/.nvm/nvm.sh || true
nvm use $NODE_VERSION

echo "Applying database migrations..."
yarn prisma:deploy

echo "Syncing slash commands..."
yarn run sync

echo "Starting Craig with PM2..."
cd apps/bot && pm2 start "ecosystem.config.js"
cd ../dashboard && pm2 start "ecosystem.config.js"
cd ../download && pm2 start "ecosystem.config.js"
cd ../tasks && pm2 start "ecosystem.config.js"

echo "Craig started. Tailing logs to keep container alive..."
pm2 logs
