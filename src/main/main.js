// src/main/main.js

const { app, Tray, Menu, BrowserWindow, ipcMain, nativeTheme } = require('electron');
const path = require('path');
const fs = require('fs');
const { startPing } = require('../services/pingService');
const { generateAllIcons } = require('../services/iconGenerator');
const { settings, saveSettings, resetSettingsToDefault } = require('../settings');
const log = require('./logger');

let tray = null;
let pingProcess = null;
let previousPingStatus = null;
let goodPingTimeout = null;

let defaultIcon, greenIcon, yellowIcon, redIcon, greenYellowIcon, greenRedIcon;
let iconDir;
let settingsWindow;
let currentIcon = null;

app.disableHardwareAcceleration();
log.info('Hardware acceleration disabled');

function updateIcons() {
  defaultIcon = path.join(iconDir, 'default.png');
  greenIcon = path.join(iconDir, 'green.png');
  yellowIcon = path.join(iconDir, 'yellow.png');
  redIcon = path.join(iconDir, 'red.png');
  greenYellowIcon = path.join(iconDir, 'green-yellow.png');
  greenRedIcon = path.join(iconDir, 'green-red.png');

  log.info('Icons paths updated');
}

const updateContextMenu = () => {
  const contextMenuTemplate = [
    {
      label: pingProcess ? 'Stop' : 'Start',
      click: () => {
        if (pingProcess) {
          stopPingProcess();
        } else {
          startPingProcess();
        }
      },
    },
    { type: 'separator' },
    {
      label: 'Settings',
      click: openSettingsWindow,
    },
    { type: 'separator' },
    {
      label: 'Quit',
      click: () => {
        if (pingProcess) stopPingProcess();
        app.quit();
      },
    },
  ];

  const contextMenu = Menu.buildFromTemplate(contextMenuTemplate);
  tray.setContextMenu(contextMenu);
  log.info('Context menu updated');
};

const startPingProcess = () => {
  if (!pingProcess) {
    pingProcess = startPing(handlePingChange);
    updateContextMenu();
    log.info('Ping process started');
  }
};

const stopPingProcess = () => {
  if (pingProcess) {
    clearInterval(pingProcess);
    pingProcess = null;
    updateIcon(defaultIcon);
    updateContextMenu();
    log.info('Ping process stopped');
  }
};

const handlePingChange = (status, pingTime) => {
  let tooltipText = pingTime !== null ? `${pingTime}ms` : 'Pingmate - Monitoring your connection';
  tray.setToolTip(tooltipText);

  switch (status) {
    case 'good':
      if (goodPingTimeout) return;
      if (previousPingStatus === 'unstable') {
        updateIcon(greenYellowIcon);
        setTemporaryIcon(greenIcon);
      } else if (previousPingStatus === 'problem') {
        updateIcon(greenRedIcon);
        setTemporaryIcon(greenIcon);
      } else {
        updateIcon(greenIcon);
      }
      break;
    case 'unstable':
      updateIcon(yellowIcon);
      clearTemporaryIcon();
      break;
    case 'problem':
      updateIcon(redIcon);
      clearTemporaryIcon();
      break;
  }

  previousPingStatus = status;
  log.info(`Ping status changed to: ${status}, pingTime: ${pingTime}`);
};

const setTemporaryIcon = (finalIcon) => {
  if (goodPingTimeout) clearTimeout(goodPingTimeout);
  goodPingTimeout = setTimeout(() => {
    updateIcon(finalIcon);
    goodPingTimeout = null;
  }, 5000);
};

const clearTemporaryIcon = () => {
  if (goodPingTimeout) {
    clearTimeout(goodPingTimeout);
    goodPingTimeout = null;
  }
};

const updateIcon = (iconPath) => {
  if (currentIcon === iconPath) {
    log.info('Icon update skipped, already set to: ' + iconPath);
    return;
  }
  tray.setImage(iconPath);
  currentIcon = iconPath;
  log.info(`Tray icon updated to: ${iconPath}`);
};

const openSettingsWindow = () => {
  if (settingsWindow) {
    settingsWindow.focus();
    return;
  }

  settingsWindow = new BrowserWindow({
    width: 440,
    height: 628,
    resizable: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
  });

  settingsWindow.loadFile(path.join(__dirname, '../renderer/settings.html'));
  applyTheme();

  settingsWindow.on('closed', () => {
    settingsWindow = null;
  });

  log.info('Settings window opened');
};

function applyTheme() {
  nativeTheme.themeSource = settings.themePreference === 'light' ? 'light' : settings.themePreference === 'dark' ? 'dark' : 'system';
  log.info(`Theme applied: ${settings.themePreference}`);
}

ipcMain.handle('get-settings', () => settings);

ipcMain.handle('reset-settings', async () => {
  resetSettingsToDefault();
  app.setLoginItemSettings({ openAtLogin: settings.startAtLogin });
  log.info(`Start at login reset to default: ${settings.startAtLogin}`);

  await generateAllIcons(iconDir, settings);
  updateIcons();

  if (pingProcess) {
    stopPingProcess();
    startPingProcess();
  }

  if (settingsWindow) {
    applyTheme();
    settingsWindow.webContents.send('update-theme', settings.themePreference);
  }

  log.info('Settings reset to default');
  return settings;
});

ipcMain.on('save-settings', (event, newSettings) => {
  const oldSettings = { ...settings };
  Object.assign(settings, newSettings);
  saveSettings();

  if (oldSettings.startAtLogin !== settings.startAtLogin) {
    app.setLoginItemSettings({ openAtLogin: settings.startAtLogin });
    log.info(`Start at login set to: ${settings.startAtLogin}`);
  }

  if (JSON.stringify(oldSettings.iconColors) !== JSON.stringify(settings.iconColors)) {
    generateAllIcons(iconDir, settings)
      .then(() => {
        updateIcons();
        handlePingChange(previousPingStatus);
        log.info('Icons updated after settings change');
      })
      .catch((error) => {
        log.error(`Error generating icons: ${error.message}`);
      });
  }

  if (
    oldSettings.pingTarget !== settings.pingTarget ||
    oldSettings.pingInterval !== settings.pingInterval ||
    oldSettings.goodPingThreshold !== settings.goodPingThreshold ||
    oldSettings.unstablePingThreshold !== settings.unstablePingThreshold
  ) {
    if (pingProcess) {
      stopPingProcess();
      startPingProcess();
      log.info('Ping process restarted after settings change');
    }
  }

  if (settingsWindow) {
    applyTheme();
    settingsWindow.webContents.send('update-theme', settings.themePreference);
  }

  event.reply('settings-saved');
  log.info('Settings saved');
});

const createTrayApp = async () => {
  try {
    iconDir = path.join(app.getPath('userData'), 'assets');

    if (!fs.existsSync(iconDir)) {
      fs.mkdirSync(iconDir, { recursive: true });
      log.info(`Created icon directory at: ${iconDir}`);
    } else {
      log.info(`Icon directory exists at: ${iconDir}`);
    }

    await generateAllIcons(iconDir, settings);
    log.info('Icons generated successfully');

    updateIcons();

    tray = new Tray(defaultIcon);
    log.info('Tray created');

    startPingProcess();
    updateContextMenu();
    tray.setToolTip('Pingmate - Monitoring your connection');
    log.info('Tray tooltip set');
  } catch (error) {
    log.error(`Error creating tray app: ${error.message}`);
  }
};

const ensureSingleInstance = () => {
  const gotTheLock = app.requestSingleInstanceLock();
  if (!gotTheLock) {
    app.quit();
  } else {
    app.on('second-instance', () => {
      if (settingsWindow) settingsWindow.focus();
    });
  }
};

ensureSingleInstance();

app.whenReady().then(() => {
  const { initSettings } = require('../settings');
  initSettings(app);
  log.info('Settings initialized');

  app.setLoginItemSettings({ openAtLogin: settings.startAtLogin });
  log.info(`Start at login initialized to: ${settings.startAtLogin}`);

  const logsDir = path.join(app.getPath('userData'), 'logs');
  if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
    log.info(`Created logs directory at: ${logsDir}`);
  } else {
    log.info(`Logs directory exists at: ${logsDir}`);
  }

  log.transports.file.resolvePath = () => path.join(logsDir, 'app.log');
  log.transports.file.format = '{h}:{i}:{s} [{level}] {text}';

  if (process.platform === 'darwin') {
    app.dock.hide();
    log.info('App dock hidden on macOS');
  }

  createTrayApp();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
    log.info('App quit');
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    openSettingsWindow();
    log.info('App activated and settings window opened');
  }
});

module.exports = {
  createTray: createTrayApp,
};