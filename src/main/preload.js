// src/main/preload.js

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  getSettings: async () => {
    try {
      return await ipcRenderer.invoke('get-settings');
    } catch (error) {
      console.error('Failed to get settings:', error);
    }
  },
  resetSettings: async () => {
    try {
      return await ipcRenderer.invoke('reset-settings');
    } catch (error) {
      console.error('Failed to reset settings:', error);
    }
  },
  saveSettings: (newSettings) => {
    try {
      ipcRenderer.send('save-settings', newSettings);
    } catch (error) {
      console.error('Failed to save settings:', error);
    }
  },
  onSettingsSaved: (callback) => ipcRenderer.on('settings-saved', callback),
  onUpdateTheme: (callback) => ipcRenderer.on('update-theme', (event, theme) => callback(theme)),
});
