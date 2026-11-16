// Diagnostics log of the Electron window: <userData>/logs/main.log
//   Linux   ~/.config/RobboJunior/logs/main.log
//   Windows %APPDATA%\RobboJunior\logs\main.log
// Chromium (GPU, sandbox, crashes) writes to chromium.log in the same folder.
// Previous run is kept as main.old.log, so a failed start can be read after a second try.

const {app} = require('electron')
const fs = require('fs')
const os = require('os')
const path = require('path')

let file = null

function line (level, args) {
  const text = args.map(a => (a instanceof Error ? (a.stack || a.message) : (typeof a === 'string' ? a : JSON.stringify(a)))).join(' ')
  return `${new Date().toISOString()} [${level}] ${text}\n`
}

function write (level, ...args) {
  if (!file) return
  try {
    fs.appendFileSync(file, line(level, args))
  } catch (e) {
    // log folder is not writable: nothing else to do
  }
}

// Before app 'ready': switches for the Chromium log must be set this early
function init () {
  try {
    const dir = path.join(app.getPath('userData'), 'logs')
    fs.mkdirSync(dir, {recursive: true})
    file = path.join(dir, 'main.log')
    if (fs.existsSync(file)) fs.renameSync(file, path.join(dir, 'main.old.log'))
    app.commandLine.appendSwitch('enable-logging', 'file')
    app.commandLine.appendSwitch('log-file', path.join(dir, 'chromium.log'))
  } catch (e) {
    file = null
    return
  }
  write('info', `start RobboJunior ${app.getVersion()} electron ${process.versions.electron} chrome ${process.versions.chrome}`)
  write('info', `os ${process.platform} ${os.release()} ${process.arch}, locale ${app.getLocale()}, host ${os.hostname()}`)
  write('info', `exec ${process.execPath}, cwd ${process.cwd()}, args ${JSON.stringify(process.argv.slice(1))}`)
  process.on('uncaughtException', error => write('fatal', 'uncaughtException', error))
  process.on('unhandledRejection', reason => write('error', 'unhandledRejection', reason))
  app.on('render-process-gone', (event, contents, details) => write('error', 'render-process-gone', details))
  app.on('child-process-gone', (event, details) => write('error', 'child-process-gone', details))
  app.on('gpu-info-update', () => write('info', 'gpu-info-update'))
  app.on('before-quit', () => write('info', 'quit'))
}

// Page events: why the window is white, which script threw, which request failed
function watch (window) {
  const contents = window.webContents
  contents.on('did-finish-load', () => write('info', 'did-finish-load'))
  contents.on('did-fail-load', (e, code, description, url, isMainFrame) =>
    write('error', 'did-fail-load', code, description, url, isMainFrame ? '(main frame)' : '(subframe)'))
  contents.on('unresponsive', () => write('error', 'window unresponsive'))
  contents.on('console-message', (e, level, message, lineNumber, sourceId) => {
    if (level >= 2) write(level === 2 ? 'warn' : 'error', 'console', `${path.basename(sourceId || '')}:${lineNumber}`, message)
  })
  window.webContents.session.webRequest.onErrorOccurred(details => write('warn', 'request failed', details.url, details.error))
}

module.exports = {init, watch, info: (...a) => write('info', ...a), warn: (...a) => write('warn', ...a), error: (...a) => write('error', ...a)}
