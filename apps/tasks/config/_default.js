module.exports = {
  // Redis, leave blank to connect to localhost:6379 with "craig:" as the prefix
  redis: process.env.REDIS_HOST ? {
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT, 10) : 6379,
    keyPrefix: 'craig:'
  } : {},

  // For drive upload in Google Drive
  drive: {
    clientId: process.env.GOOGLE_CLIENT_ID || '',
    clientSecret: process.env.GOOGLE_CLIENT_SECRET || ''
  },

  // For drive upload in Microsoft OneDrive
  microsoft: {
    clientId: process.env.MICROSOFT_CLIENT_ID || '',
    clientSecret: process.env.MICROSOFT_CLIENT_SECRET || '',
    redirect: process.env.MICROSOFT_REDIRECT || ''
  },

  // For drive upload in Dropbox
  dropbox: {
    clientId: process.env.DROPBOX_CLIENT_ID || '',
    clientSecret: process.env.DROPBOX_CLIENT_SECRET || '',
    folderName: 'CraigChat'
  },

  // for refresh patrons job
  patreon: {
    campaignId: process.env.PATREON_CAMPAIGN_ID ? parseInt(process.env.PATREON_CAMPAIGN_ID, 10) : 0,
    accessToken: process.env.PATREON_ACCESS_TOKEN || '',
    tiers: process.env.PATREON_TIER_MAP ? JSON.parse(process.env.PATREON_TIER_MAP) : {},
    skipUsers: []
  },

  downloads: {
    expiration: 24 * 60 * 60 * 1000,
    path: '../download/downloads'
  },

  recording: {
    fallbackExpiration: 87600 * 60 * 60 * 1000,
    path: '../../rec',
    skipIds: []
  },

  timezone: 'America/New_York',
  loggerLevel: 'debug',
  tasks: {
    ignore: []
  }
};
