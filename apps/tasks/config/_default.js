module.exports = {
  // Redis, leave blank to connect to localhost:6379 with "craig:" as the prefix
  redis: process.env.REDIS_HOST ? {
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT, 10) : 6379,
    keyPrefix: 'craig:'
  } : {},

  // For drive upload in Google Drive
  drive: {
    clientId: '',
    clientSecret: ''
  },

  // For drive upload in Microsoft OneDrive
  microsoft: {
    clientId: '',
    clientSecret: '',
    redirect: ''
  },

  // For drive upload in Dropbox
  dropbox: {
    clientId: '',
    clientSecret: '',
    folderName: 'CraigChat'
  },

  // for refresh patrons job
  patreon: {
    campaignId: 0,
    accessToken: '',
    tiers: {},
    skipUsers: []
  },

  downloads: {
    expiration: 24 * 60 * 60 * 1000,
    path: '../download/downloads'
  },

  recording: {
    fallbackExpiration: 24 * 60 * 60 * 1000,
    path: '../../rec',
    skipIds: []
  },

  timezone: 'America/New_York',
  loggerLevel: 'debug',
  tasks: {
    ignore: []
  }
};
