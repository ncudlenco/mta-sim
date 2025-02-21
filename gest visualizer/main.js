const { app, BrowserWindow, dialog, ipcMain } = require('electron')
const fs = require('fs');
const path = require('path');
require('electron-reload')(__dirname, {
    electron: path.join(__dirname, 'node_modules', '.bin', 'electron')
});

const createWindow = () => {
    const win = new BrowserWindow({
        width: 800,
        height: 600,
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false
        }
    })

    win.loadFile('index.html')
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

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit()
})