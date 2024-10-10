// src/settings.js

const fs = require('fs');
const path = require('path');

let settingsPath;
const defaultSettings = {
  pingTarget: '8.8.8.8',
  pingInterval: 1000,
  goodPingThreshold: 50,
  unstablePingThreshold: 250,
  startAtLogin: false,
  iconColors: {
    good: '#00a245',
    unstable: '#EAA93B',
    problem: '#AE3B36',
    default: '#808080',
  },
  themePreference: 'system',
};

let settings = {}; // Initially empty object

function initSettings(app) {
  settingsPath = path.join(app.getPath('userData'), 'settings.json');
  console.log('Settings file path:', settingsPath);
  loadSettings();
}

function loadSettings() {
  try {
    if (fs.existsSync(settingsPath)) {
      console.log('Loading settings from file.');
      const data = fs.readFileSync(settingsPath, 'utf-8');
      const loadedSettings = JSON.parse(data);
      console.log('Loaded settings content:', loadedSettings);

      // Deep merge settings without overwriting the settings object
      Object.assign(settings, defaultSettings, loadedSettings);
      settings.iconColors = Object.assign({}, defaultSettings.iconColors, loadedSettings.iconColors);

      console.log('Settings after loading and merging:', settings);
    } else {
      console.log('Settings file not found. Using default settings.');
      Object.assign(settings, defaultSettings);
      saveSettings();
    }
  } catch (err) {
    console.error('Error loading settings:', err);
    Object.assign(settings, defaultSettings);
    saveSettings();
  }
}

function saveSettings() {
  try {
    console.log('Saving settings to file:', settingsPath);
    fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
    console.log('Settings saved successfully.');
  } catch (err) {
    console.error('Error saving settings:', err);
  }
}

function resetSettingsToDefault(saveImmediately = true) {
  Object.assign(settings, defaultSettings);
  if (saveImmediately) {
    saveSettings();
  }
}

module.exports = {
  settings,
  initSettings,
  saveSettings,
  resetSettingsToDefault,
};