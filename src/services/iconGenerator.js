// src/services/iconGenerator.js

const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

function generateAllIcons(iconDir, settings) {
  if (!iconDir) {
    throw new Error('Icon directory is not defined!');
  }

  if (!settings || !settings.iconColors) {
    throw new Error('Icon settings are not defined!');
  }

  const colors = settings.iconColors;
  const assetsDir = path.join(process.resourcesPath, 'assets'); // Path to original SVG files

  const icons = [
    { name: 'default', svg: `<circle cx="50" cy="50" r="35" fill="${colors.default}"/>` },
    { name: 'green', svg: `<circle cx="50" cy="50" r="35" fill="${colors.good}"/>` },
    { name: 'yellow', svg: `<circle cx="50" cy="50" r="35" fill="${colors.unstable}"/>` },
    { name: 'red', svg: `<circle cx="50" cy="50" r="35" fill="${colors.problem}"/>` },
    {
      name: 'green-yellow',
      svg: `
        <circle cx="50" cy="50" r="35" fill="none" stroke="${colors.unstable}" stroke-width="10"/>
        <circle cx="50" cy="50" r="20" fill="${colors.good}"/>
      `,
    },
    {
      name: 'green-red',
      svg: `
        <circle cx="50" cy="50" r="35" fill="none" stroke="${colors.problem}" stroke-width="10"/>
        <circle cx="50" cy="50" r="20" fill="${colors.good}"/>
      `,
    },
  ];

  const promises = icons.map((icon) => {
    const svgContent = `
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
        ${icon.svg}
      </svg>
    `;
    return generateIcon(svgContent, iconDir, icon.name);
  });

  return Promise.all(promises)
    .then(() => console.log('Icons generated successfully'))
    .catch((error) => {
      console.error('Error generating icons:', error);
      throw error;
    });
}

function generateIcon(svgContent, outputPath, iconName) {
  const iconPath = path.join(outputPath, `${iconName}.png`);

  return sharp(Buffer.from(svgContent))
    .resize({ width: 24, height: 24 })
    .png()
    .toFile(iconPath)
    .catch((error) => {
      console.error(`Error converting SVG to PNG for icon "${iconName}":`, error);
      throw error;
    });
}

module.exports = {
  generateAllIcons,
};
