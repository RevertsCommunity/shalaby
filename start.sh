#!/bin/bash

# Node/Yarn/PM2 are on PATH via Dockerfile ENV (no need to source nvm)

echo "Applying database migrations..."
yarn prisma:deploy

echo "Syncing slash commands..."
yarn run sync

echo "Starting Craig with PM2..."
cd /app/apps/bot && pm2 start "ecosystem.config.js"
cd /app/apps/dashboard && pm2 start "ecosystem.config.js"
cd /app/apps/download && pm2 start "ecosystem.config.js"
cd /app/apps/tasks && pm2 start "ecosystem.config.js"

echo "Craig started. Tailing logs to keep container alive..."
pm2 logs
