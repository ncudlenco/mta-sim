const { app, BrowserWindow, dialog, ipcMain } = require('electron')
const fs = require('fs');
const path = require('path');
require('electron-reload')(__dirname, {
    electron: path.join(__dirname, 'node_modules', '.bin', 'electron')
});

// Parse command-line arguments for headless mode
const args = process.argv.slice(2);
const headlessMode = args.includes('--headless');
const inputFile = args.find(arg => arg.endsWith('.json') && !arg.startsWith('--'));
const outputArg = args.find(arg => arg.startsWith('--output='));
const outputFile = outputArg ? outputArg.replace('--output=', '') : null;

// Timeout for headless mode to prevent hanging
let exportTimeout = null;

const createWindow = () => {
    const win = new BrowserWindow({
        width: headlessMode ? 2400 : 800,
        height: headlessMode ? 1600 : 600,
        show: !headlessMode,
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false,
            offscreen: headlessMode
        }
    })

    win.loadFile('index.html')

    // Handle headless mode
    if (headlessMode) {
        if (!inputFile) {
            console.error('Error: No input file specified for headless mode');
            console.error('Usage: electron . --headless <input.json> [--output=<output.png>]');
            app.quit();
            return;
        }

        const inputPath = path.resolve(inputFile);
        if (!fs.existsSync(inputPath)) {
            console.error(`Error: Input file not found: ${inputPath}`);
            app.quit();
            return;
        }

        const defaultOutput = inputPath.replace('.json', '.png');
        const finalOutputPath = outputFile ? path.resolve(outputFile) : defaultOutput;

        console.log(`Headless mode: Rendering ${inputPath}`);
        console.log(`Output will be saved to: ${finalOutputPath}`);

        // Set timeout safety fallback
        exportTimeout = setTimeout(() => {
            console.error('Error: Export timeout (30s) - process hung');
            app.quit();
        }, 30000);

        // Send file info to renderer when ready
        win.webContents.on('did-finish-load', () => {
            win.webContents.send('load-file-headless', {
                inputPath: inputPath,
                outputPath: finalOutputPath
            });
        });
    }

    return win;
}

app.whenReady().then(() => {
    createWindow()
})

ipcMain.handle('open-file-dialog', async () => {
    const result = await dialog.showOpenDialog({
        properties: ['openFile'],
        filters: [{ name: 'JSON Files', extensions: ['json'] }]
    });
    return result;
});

ipcMain.handle('save-file-dialog', async (event) => {

    const result = await dialog.showSaveDialog({
        title: 'Save PNG',
        defaultPath: 'graph.png',
        filters: [{ name: 'Images', extensions: ['png'] }]
    });

    return result.filePath;
});

// IPC handler for headless export completion
ipcMain.on('export-complete', (event, outputPath) => {
    if (headlessMode) {
        clearTimeout(exportTimeout);
        console.log(`Successfully exported to: ${outputPath}`);
        app.quit();
    }
});

// IPC handler for headless export errors
ipcMain.on('export-error', (event, error) => {
    if (headlessMode) {
        clearTimeout(exportTimeout);
        console.error(`Export error: ${error}`);
        process.exit(1);
    }
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit()
})