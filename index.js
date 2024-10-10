// index.js

const { app } = require('electron');
const path = require('path');
const fs = require('fs');
const { createTray } = require('./src/main/main');
const { initSettings } = require('./src/settings');

app.disableHardwareAcceleration();

const iconDir = path.join(app.getPath('userData'), 'assets');

try {
  fs.mkdirSync(iconDir, { recursive: true });
} catch (error) {
  console.error('Failed to create icon directory:', error);
}

app.whenReady().then(() => {
  initSettings(app);

  if (process.platform === 'darwin') {
    app.dock.hide();
  }

  createTray(iconDir);
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('ready', () => {
  console.log('Application is ready');
});

app.on('before-quit', () => {
  console.log('Application is about to quit');
});
