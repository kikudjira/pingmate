// src/services/pingService.js

const ping = require('ping');
const { settings } = require('../settings');

function startPing(callback) {
  console.log(`Starting ping for target ${settings.pingTarget} with interval ${settings.pingInterval}ms`);

  const intervalId = setInterval(async () => {
    try {
      const res = await ping.promise.probe(settings.pingTarget);

      if (res.alive) {
        const pingTime = res.time;

        if (pingTime <= settings.goodPingThreshold) {
          callback('good', pingTime);
        } else if (pingTime <= settings.unstablePingThreshold) {
          callback('unstable', pingTime);
        } else {
          callback('problem', pingTime);
        }
      } else {
        console.warn(`Target ${settings.pingTarget} is not responding.`);
        callback('problem', null);
      }
    } catch (error) {
      console.error(`Ping error for target ${settings.pingTarget}:`, error);
      callback('problem', null);
    }
  }, settings.pingInterval);

  return intervalId;
}

module.exports = {
  startPing,
};
