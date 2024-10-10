// src/renderer/settings.js

const settingsForm = (() => {
  let settings;
  let originalSettingsJSON;

  window.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('settings-form');
    const saveButton = document.getElementById('save-button');
    const resetButton = document.getElementById('reset-button');
    const statusMessage = document.getElementById('status-message');

    initialize();

    async function initialize() {
      try {
        settings = await window.electronAPI.getSettings();
        populateFormFields(settings);
        originalSettingsJSON = JSON.stringify(getCurrentSettings());
        saveButton.disabled = true;

        addEventListeners();
      } catch (error) {
        console.error('Failed to load settings:', error);
        statusMessage.textContent = 'Failed to load settings.';
      }
    }

    function populateFormFields(settings) {
      const ipParts = settings.pingTarget.split('.');
      ['pingTarget1', 'pingTarget2', 'pingTarget3', 'pingTarget4'].forEach(
        (id, index) => {
          document.getElementById(id).value = ipParts[index] || '';
        }
      );

      ['pingInterval', 'goodPingThreshold', 'unstablePingThreshold'].forEach((field) => {
        document.getElementById(field).value = settings[field];
      });

      ['goodColor', 'unstableColor', 'problemColor'].forEach((field) => {
        document.getElementById(field).value = settings.iconColors[field.replace('Color', '')];
      });
    }

    function addEventListeners() {
      Array.from(form.elements).forEach((element) => {
        element.addEventListener('input', onFormChange);
      });

      form.addEventListener('submit', onFormSubmit);
      resetButton.addEventListener('click', onResetClick);
      
      // Add input listeners to limit IP fields to 3 digits
      ['pingTarget1', 'pingTarget2', 'pingTarget3', 'pingTarget4'].forEach((fieldId) => {
        const input = document.getElementById(fieldId);
        input.addEventListener('input', () => {
          if (input.value.length > 3) {
            input.value = input.value.slice(0, 3);
          }
        });
      });

      window.electronAPI.onUpdateTheme((theme) => {
        document.body.classList.remove('light-theme', 'dark-theme');
        document.body.classList.add(`${theme}-theme`);
      });
    }

    function onFormChange() {
      const currentSettings = getCurrentSettings();
      saveButton.disabled = JSON.stringify(currentSettings) === originalSettingsJSON;
      statusMessage.textContent = '';
    }

    function getCurrentSettings() {
      const pingTarget = [
        'pingTarget1',
        'pingTarget2',
        'pingTarget3',
        'pingTarget4',
      ]
        .map((id) => document.getElementById(id).value)
        .join('.');

      return {
        pingTarget,
        pingInterval: parseInt(document.getElementById('pingInterval').value, 10),
        goodPingThreshold: parseInt(document.getElementById('goodPingThreshold').value, 10),
        unstablePingThreshold: parseInt(document.getElementById('unstablePingThreshold').value, 10),
        iconColors: {
          good: document.getElementById('goodColor').value,
          unstable: document.getElementById('unstableColor').value,
          problem: document.getElementById('problemColor').value,
          default: settings.iconColors.default,
        },
      };
    }

    function onFormSubmit(e) {
      e.preventDefault();
      if (!validateInput()) return;

      const newSettings = getCurrentSettings();
      window.electronAPI.saveSettings(newSettings);

      originalSettingsJSON = JSON.stringify(newSettings);
      saveButton.disabled = true;
      statusMessage.textContent = 'Settings saved successfully.';
    }

    async function onResetClick() {
      if (!confirm('Are you sure you want to reset settings to default values?')) return;

      try {
        settings = await window.electronAPI.resetSettings();
        populateFormFields(settings);
        originalSettingsJSON = JSON.stringify(getCurrentSettings());
        saveButton.disabled = true;
        statusMessage.textContent = 'Settings have been reset to default values.';
      } catch (error) {
        console.error('Failed to reset settings:', error);
        statusMessage.textContent = 'Failed to reset settings.';
      }
    }

    function validateInput() {
      let isValid = true;
      let errorMessages = [];

      // Validate IP fields
      ['pingTarget1', 'pingTarget2', 'pingTarget3', 'pingTarget4'].forEach((fieldId) => {
        const value = parseInt(document.getElementById(fieldId).value, 10);
        if (isNaN(value) || value < 0 || value > 255) {
          isValid = false;
          errorMessages.push('Please enter a valid IP address (0-255 in each field).');
        }
      });

      // Validate number fields
      ['pingInterval', 'goodPingThreshold', 'unstablePingThreshold'].forEach((fieldId) => {
        const value = parseInt(document.getElementById(fieldId).value, 10);
        if (isNaN(value) || value <= 0) {
          isValid = false;
          errorMessages.push(`Please enter a positive number for ${fieldId}`);
        }
      });

      if (!isValid) {
        alert(errorMessages.join('\n'));
      }

      return isValid;
    }
  });
})();
