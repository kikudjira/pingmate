<img src="/assets/icon_128x128@2x.png" align="left" height="64" />

# Ping Mate

Ping Mate is a simple Electron-based application that monitors the quality of your internet connection in real-time and provides visual feedback through the system tray icon. The application is designed for macOS and provides a user-friendly interface to customize ping settings and customize color indicators.

## Features

- Monitors internet connection quality using ICMP ping requests.
- Changes system tray icon color to indicate the status of the internet connection (Good, Unstable, Problem).
- Settings panel to customize ping intervals, thresholds, and color indicators.
- Supports both light and dark themes.
- Allows configuring the application to start automatically on login (manual setup required).

## System Requirements

- macOS 10.13 or later.
- Node.js and npm installed.

## Download the Latest Version

You can download the latest `.dmg` build of Ping Mate [here](https://drive.google.com/file/d/1o_Xu_NcHxM6OM_uwzxpUo4O63y9tUJg4/view?usp=sharing).

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/en/download/) (v14 or later).
- [Git](https://git-scm.com/downloads) (optional, for cloning the repository).

### Setup

1. **Clone the repository**:

   ```sh
   git clone git@github.com:kikudjira/pingmate.git
   cd pingmate
   ```

2. **Install dependencies**:

   ```sh
   npm install
   ```

### Running in Development Mode

To start the application in development mode:

```sh
npm start
```

This will launch the Electron app, allowing you to see the real-time tray icon status based on your internet connection.

### Building the Application

To build the application for distribution:

```sh
npm run build
```

This command will create a distributable `.dmg` file for macOS in the `dist` directory.

### License

Ping Mate is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.

## Author

- Andrey Sekirkin (@Kikudjira)
