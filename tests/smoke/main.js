// Smoke test runner: starts the real desktop/main.js and drives its window with real mouse events.
// No test framework: it would tie the tests to an Electron version, and the Electron upgrade is
// exactly what they have to guard. Started by tests/run.sh with a temporary HOME.

const {app, BrowserWindow} = require('electron')
const fs = require('fs')
const http = require('http')
const path = require('path')

const APP_DIR = process.env.RJ_APP_DIR
const OUT_DIR = process.env.RJ_TEST_OUT
const ONLY = process.env.RJ_TEST_ONLY
// Decode error: IO.js tries atob on every file of a .sjr and keeps the file as it is when that fails
const IGNORED_ERRORS = /Electron Security Warning|Decode error/

app.setName('RobboJunior')

// Real mirrors stay out of the tests: the update check runs against a local one in scenarios.js
require(path.join(APP_DIR, 'update-check.js')).start = () => {}
require(path.join(APP_DIR, 'main.js'))

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))

async function until (what, condition, timeout = 8000) {
  const end = Date.now() + timeout
  for (;;) {
    const value = await condition()
    if (value) return value
    if (Date.now() > end) throw new Error('не дождались: ' + what)
    await sleep(100)
  }
}

// Panel stub: the real panel needs a robot. mode: robot, none (answers with an error), like the panel
function startPanel () {
  const panel = {mode: 'robot', requests: []}
  const server = http.createServer((request, response) => {
    panel.requests.push(request.url)
    response.setHeader('Access-Control-Allow-Origin', '*')
    if (request.url.includes('rob_check')) {
      response.end(panel.mode === 'robot' && request.url.includes('/def/0/') ? '0\n0\n0\n0\n0,0,0,0\n-1' : 'error=1')
    } else {
      response.end('0')
    }
  })
  panel.server = server
  return new Promise((resolve, reject) => {
    server.on('error', reject)
    server.listen(9876, '127.0.0.1', () => resolve(panel))
  })
}

function makeContext (wc, panel) {
  const context = {
    wc,
    panel,
    sleep,
    until,
    appDir: APP_DIR,
    outDir: OUT_DIR,
    errors: [],
    ev: code => wc.executeJavaScript(code),
    url: () => wc.getURL(),
    async box (selector) {
      const box = await wc.executeJavaScript(`(() => {
        const element = ${selector}
        if (!element) return null
        const r = element.getBoundingClientRect()
        return {x: Math.round(r.x + r.width / 2), y: Math.round(r.y + r.height / 2)}
      })()`)
      if (!box) throw new Error('нет элемента: ' + selector)
      return box
    },
    move (x, y, pressed) {
      wc.sendInputEvent({type: 'mouseMove', x, y, button: pressed ? 'left' : undefined, modifiers: pressed ? ['leftButtonDown'] : []})
    },
    async click (selector) {
      const {x, y} = await context.box(selector)
      context.move(x, y)
      await sleep(50)
      wc.sendInputEvent({type: 'mouseDown', x, y, button: 'left', clickCount: 1})
      await sleep(80)
      wc.sendInputEvent({type: 'mouseUp', x, y, button: 'left', clickCount: 1})
      await sleep(200)
    },
    async drag (fromSelector, toSelector) {
      const from = await context.box(fromSelector)
      const to = await context.box(toSelector)
      context.move(from.x, from.y)
      await sleep(60)
      wc.sendInputEvent({type: 'mouseDown', x: from.x, y: from.y, button: 'left', clickCount: 1})
      await sleep(120)
      for (let i = 1; i <= 12; i++) {
        context.move(from.x + (to.x - from.x) * i / 12, from.y + (to.y - from.y) * i / 12, true)
        await sleep(25)
      }
      wc.sendInputEvent({type: 'mouseUp', x: to.x, y: to.y, button: 'left', clickCount: 1})
      await sleep(500)
    },
    async open (page) {
      await wc.loadURL('file://' + path.join(APP_DIR, page))
      await sleep(300)
    },
    async shot (name) {
      const image = await wc.capturePage()
      fs.writeFileSync(path.join(OUT_DIR, name + '.png'), image.toPNG())
    }
  }
  return context
}

app.whenReady().then(async () => {
  const panel = await startPanel()
  await sleep(1500)
  const window = BrowserWindow.getAllWindows()[0]
  window.setSize(1280, 800)
  const wc = window.webContents
  const context = makeContext(wc, panel)
  wc.on('console-message', (event, level, message) => {
    if (level >= 3 && !IGNORED_ERRORS.test(message)) context.errors.push(message.slice(0, 300))
  })
  wc.on('render-process-gone', (event, details) => context.errors.push('renderer gone: ' + details.reason))

  const scenarios = require('./scenarios')
  let failed = 0
  for (const [name, run] of scenarios) {
    if ((ONLY && !name.includes(ONLY)) || (!ONLY && name.includes('старый профиль'))) continue
    context.errors.length = 0
    try {
      await run(context)
      if (context.errors.length) throw new Error('ошибки на странице: ' + context.errors.slice(0, 3).join(' | '))
      console.log('[ OK ] ' + name)
    } catch (error) {
      failed++
      console.log('[FAIL] ' + name + ': ' + error.message.replace(/\s+/g, ' '))
      await context.shot('fail-' + name.replace(/[^\p{L}\p{N}]+/gu, '-')).catch(() => {})
    }
  }
  console.log(failed ? `Провалено: ${failed}` : 'Все сценарии прошли')
  app.exit(failed ? 1 : 0)
}).catch(error => {
  console.log('[FAIL] запуск: ' + error.message)
  app.exit(1)
})
