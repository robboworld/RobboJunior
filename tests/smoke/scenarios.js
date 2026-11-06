// Scenarios run in order in one profile: later ones use the project made by the earlier ones.

const {app, BrowserWindow, dialog, shell} = require('electron')
const assert = require('assert')
const fs = require('fs')
const http = require('http')
const path = require('path')

const ROBOT_TAB = `document.getElementById('selectors').children[6]`
const STATUS = `document.getElementById('robot_connection_status')`
const paletteBlock = type => `[...document.querySelectorAll('#palette *')].filter(e => e.owner && e.owner.blocktype == '${type}')[0]`
const scriptBlock = type => `[...document.querySelectorAll('#scripts *')].filter(e => e.owner && e.owner.blocktype == '${type}')[0]`
const homeLoaded = t => t.until('главный экран', () => t.ev(`!!document.getElementById('newproject')`))
const SPRITE_NAME = `document.querySelector('.sname')`
const spriteName = t => t.ev(`${SPRITE_NAME} ? (${SPRITE_NAME}.value || ${SPRITE_NAME}.textContent) : ''`)
const editorLoaded = t => t.until('редактор', () => spriteName(t), 15000)
const statusColor = t => t.ev(`${STATUS}.style.backgroundColor`)
const projects = t => t.ev(`[...document.querySelectorAll('#scrollarea > *')].map(e => e.id).filter(id => id && id != 'newproject')`)
const powerCommands = t => t.panel.requests.filter(url => url.includes('rob_power'))

// The editor takes clicks only when it has finished loading, so the tab is clicked until it opens
async function openRobotTab (t) {
  await t.until('палитра робота', async () => {
    await t.click(ROBOT_TAB)
    return t.ev(`!!${paletteBlock('robot_forward')}`)
  }, 15000)
}

async function newProjectWithBlock (t) {
  await t.click(`document.getElementById('newproject')`)
  await editorLoaded(t)
  await openRobotTab(t)
  await t.drag(paletteBlock('robot_forward'), `document.getElementById('scripts')`)
  await t.until('блок в скрипте', () => t.ev(`!!${scriptBlock('robot_forward')}`))
}

async function runBlock (t, steps) {
  await t.ev(`(${scriptBlock('robot_forward')}).owner.getArgValue = () => ${steps}; 1`)
  await t.click(scriptBlock('robot_forward'))
}

function localMirror (routes) {
  const server = http.createServer((request, response) => {
    const route = routes[request.url]
    if (route === undefined) {
      response.statusCode = 404
      response.end()
    } else {
      response.end(typeof route === 'string' ? route : JSON.stringify(route))
    }
  })
  return new Promise(resolve => server.listen(0, '127.0.0.1', () => resolve(server)))
}

module.exports = [
  ['главный экран и русский язык', async t => {
    await t.open('home.html')
    await homeLoaded(t)
    assert.strictEqual(await t.ev('navigator.language'), 'ru')
    assert.match(await t.ev(`document.getElementById('tabheader').textContent`), /Мои проекты/)
  }],

  ['что нового: точка и окно по клику на версию', async t => {
    await t.until('точка на версии', () => t.ev(`document.getElementById('version').className.includes('unread')`))
    const version = `document.getElementById('version')`
    await t.click(version)
    assert(await t.ev(`!!document.querySelector('.whatsnew-overlay')`), 'окно не открылось')
    assert(await t.ev(`document.querySelector('.whatsnew-list h2').textContent.length > 0`))
    assert(!(await t.ev(`${version}.className.includes('unread')`)), 'точка не погасла')
    await t.click(version)
    assert(!(await t.ev(`!!document.querySelector('.whatsnew-overlay')`)), 'повторный клик не закрыл окно')
    await t.wc.reload()
    await homeLoaded(t)
    await t.sleep(500)
    assert(!(await t.ev(`${version}.className.includes('unread')`)), 'точка вернулась после перезагрузки')
  }],

  ['подписи: нет сырых ключей', async t => {
    await newProjectWithBlock(t)
    assert.match(await spriteName(t), /^Рыба/)
  }],

  ['робот: определение и окончание блока', async t => {
    await t.until('зелёный индикатор', async () => (await statusColor(t)) === 'green')
    t.panel.requests.length = 0
    await runBlock(t, 3)
    await t.until('конец блока', () => powerCommands(t).includes('/txt/def/0/rob_power/00/00'))
    assert(powerCommands(t).includes('/txt/def/0/rob_power/13/13'), 'нет команды движения')
    const sent = powerCommands(t).length
    await t.sleep(500)
    assert.strictEqual(powerCommands(t).length, sent, 'команды после конца блока')
  }],

  ['робот: стоп обрывает длинный блок', async t => {
    t.panel.requests.length = 0
    await runBlock(t, 50)
    await t.until('движение', () => powerCommands(t).length >= 3)
    await t.click(`document.getElementById('resetall')`)
    await t.until('команда остановки', () => powerCommands(t).at(-1).endsWith('/00/00'))
    const sent = powerCommands(t).length
    await t.sleep(700)
    assert.strictEqual(powerCommands(t).length, sent, 'робот получает команды после стопа')
  }],

  ['робот: блок стоп есть в палитре', async t => {
    await t.until('блок стоп', () => t.ev(`!!${paletteBlock('robot_stop')}`))
  }],

  ['проект сохраняется и открывается', async t => {
    await t.click(`document.getElementById('flip')`)
    await homeLoaded(t)
    await t.until('проект в списке', async () => (await projects(t)).length > 0)
    t.projectId = (await projects(t))[0]
    await t.click(`document.getElementById('${t.projectId}')`)
    await editorLoaded(t)
    await openRobotTab(t)
    await t.until('блок после открытия', () => t.ev(`!!${scriptBlock('robot_forward')}`))
  }],

  ['робот: нет робота, затем появился', async t => {
    t.panel.mode = 'none'
    t.panel.requests.length = 0
    await t.wc.reload()
    await editorLoaded(t)
    await t.until('красный индикатор', async () => (await statusColor(t)) === 'red')
    await openRobotTab(t)
    await t.until('блок в скрипте', () => t.ev(`!!${scriptBlock('robot_forward')}`))
    await runBlock(t, 1)
    await t.until('сообщение', () => t.ev(`[...document.querySelectorAll('canvas')].some(c => c.style.zIndex == '1000')`))
    assert.strictEqual(powerCommands(t).length, 0, 'команды без робота')
    t.panel.mode = 'robot'
    await t.until('индикатор сам стал зелёным', async () => (await statusColor(t)) === 'green', 6000)
  }],

  ['.sjr: выгрузка и загрузка', async t => {
    const file = path.join(t.outDir, 'project.sjr')
    t.wc.session.once('will-download', (event, item) => item.setSavePath(file))
    await t.click(`document.getElementById('project_save')`)
    await t.sleep(500)
    await t.ev(`[...document.querySelectorAll('div')].filter(d => d.textContent == 'Сохранить в файл' && !d.children.length).forEach(d => { d.dispatchEvent(new MouseEvent('mousedown', {bubbles: true})); d.dispatchEvent(new MouseEvent('mouseup', {bubbles: true})); d.click() }); 1`)
    await t.until('файл .sjr', () => fs.existsSync(file) && fs.statSync(file).size > 1000)
    assert.strictEqual(fs.readFileSync(file).slice(0, 2).toString(), 'PK', 'не zip')

    await t.open('home.html')
    await homeLoaded(t)
    await t.until('проект в списке', async () => (await projects(t)).length > 0)
    const before = (await projects(t)).length
    await t.ev(`window.OS.loadProjectFromSjr(${JSON.stringify(fs.readFileSync(file).toString('base64'))}); 1`)
    await t.until('загруженный проект', async () => {
      await t.sleep(300)
      return (await t.ev(`!!document.getElementById('newproject')`)) && (await projects(t)).length === before + 1
    }, 15000)
  }],

  ['старый профиль: все проекты открываются', async t => {
    await t.open('home.html')
    await homeLoaded(t)
    await t.until('проекты', async () => (await projects(t)).length > 0, 15000)
    const ids = await projects(t)
    for (const id of ids) {
      await t.open('home.html')
      await homeLoaded(t)
      await t.until('проект ' + id, () => t.ev(`!!document.getElementById('${id}')`))
      await t.click(`document.getElementById('${id}')`)
      await editorLoaded(t)
      assert(!(await t.ev(`[...document.querySelectorAll('canvas')].some(c => c.style.zIndex == '1000')`)), `проект ${id}: сообщение об ошибке`)
    }
    console.log(`       открыто проектов: ${ids.length}`)
  }],

  ['число в блоке вводится с клавиатуры', async t => {
    await t.open('home.html')
    await homeLoaded(t)
    await newProjectWithBlock(t)
    const value = `(${scriptBlock('robot_forward')}).owner.getArgValue()`
    await t.ev(`(${scriptBlock('robot_forward')}).owner.arg.div.dispatchEvent(new MouseEvent('mousedown', {bubbles: true})); 1`)
    await t.sleep(200)
    await t.ev(`(${scriptBlock('robot_forward')}).owner.arg.div.dispatchEvent(new MouseEvent('mouseup', {bubbles: true})); 1`)
    await t.sleep(300)
    t.wc.sendInputEvent({type: 'keyDown', keyCode: '7'})
    t.wc.sendInputEvent({type: 'char', keyCode: '7'})
    t.wc.sendInputEvent({type: 'keyUp', keyCode: '7'})
    await t.until('значение 7', async () => String(await t.ev(value)).includes('7'), 3000)
  }],

  ['язык: региональный вариант включается в настройках', async t => {
    const choose = async name => {
      await t.open('home.html?place=gear')
      await t.until('список языков', () => t.ev(`document.querySelectorAll('.localizationselect').length >= 23`))
      await t.click(`[...document.querySelectorAll('.localizationselect')].find(e => e.textContent == '${name}')`)
      await t.sleep(800)
      await t.open('home.html')
      await homeLoaded(t)
    }
    await choose('简体中文')
    await t.until('китайский', async () => (await t.ev(`document.getElementById('tabheader').textContent`)) === '我的项目')
    await choose('Русский')
    await t.until('русский', async () => /Мои проекты/.test(await t.ev(`document.getElementById('tabheader').textContent`)))
  }],

  // The samples screen is hidden and is not tested: samples/Friends.txt, the only one in media.json,
  // needs sprites and backgrounds that are no longer in svglibrary/.
  ['справка: кнопка на главном экране и все вкладки', async t => {
    await t.open('home.html')
    await homeLoaded(t)
    const helpText = () => t.ev(`(() => { const f = document.querySelector('iframe'); return f && f.contentDocument.body ? f.contentDocument.body.innerText : '' })()`)
    // The home screen ignores clicks while it loads the projects
    await t.until('страница о программе', async () => {
      await t.click(`document.getElementById('booktab')`)
      await t.sleep(500)
      return /Что такое Robbo Junior/.test(await helpText())
    }, 12000)
    for (const tab of ['abouttab', 'interfacetab', 'painttab', 'blockstab']) {
      await t.until('вкладка ' + tab, async () => {
        await t.click(`document.getElementById('${tab}')`)
        return (await t.ev(`document.getElementById('${tab}').className.includes('on')`)) && (await helpText()).length > 20
      })
      if (tab !== 'abouttab') assert(!/ScratchJr/.test(await helpText()), tab + ': осталось название ScratchJr')
    }
    await t.until('раздел робота', () => t.ev(`(() => { const e = document.querySelector('iframe').contentDocument.getElementById('robot-block-category-header'); return !!e && e.textContent == 'Блоки робота' })()`))
  }],

  ['справка: номера на схеме нажимаются мышью', async t => {
    await t.click(`document.getElementById('interfacetab')`)
    await t.until('схема', () => t.ev(`!!document.querySelector('iframe').contentDocument.getElementById('interface-button-robot')`))
    await t.sleep(300)
    const frame = `document.querySelector('iframe')`
    const number = `${frame}.contentDocument.querySelector('#interface-button-robot .interface-button-text')`
    const box = await t.ev(`(() => { const f = ${frame}.getBoundingClientRect(); const r = ${number}.getBoundingClientRect(); return {x: Math.round(f.x + r.x + r.width / 2), y: Math.round(f.y + r.y + r.height / 2)} })()`)
    t.move(box.x, box.y)
    await t.sleep(50)
    t.wc.sendInputEvent({type: 'mouseDown', x: box.x, y: box.y, button: 'left', clickCount: 1})
    await t.sleep(80)
    t.wc.sendInputEvent({type: 'mouseUp', x: box.x, y: box.y, button: 'left', clickCount: 1})
    await t.until('описание индикатора', () => t.ev(`${frame}.contentDocument.getElementById('interface-key-header').textContent.includes('Индикатор робота')`))

  }],

  ['палитра на экране 4:3', async t => {
    const window = BrowserWindow.getAllWindows()[0]
    window.setContentSize(1024, 768)
    await t.sleep(300)
    await t.open('home.html')
    await homeLoaded(t)
    await t.click(`document.getElementById('newproject')`)
    await editorLoaded(t)
    await t.sleep(500)
    const top = id => t.ev(`Math.round(document.getElementById('${id}').getBoundingClientRect().top)`)
    assert.strictEqual(await top('palette'), await top('selectors'), 'палитра ушла со строки категорий')
    window.setContentSize(1280, 800)
  }],

  ['обновления: зеркала, один показ на версию, чужая ссылка', async t => {
    const updates = require(path.join(t.appDir, 'update-check.js'))
    const compare = updates.compareVersions
    assert(compare('1.0.0', '1.0.0-alpha') > 0)
    assert(compare('1.0.0-2', '1.0.0') > 0)
    assert(compare('1.0.10', '1.0.9') > 0)
    assert(compare('1.0.0-rc.10', '1.0.0-rc.9') > 0)

    const window = BrowserWindow.getAllWindows()[0]
    const version = app.getVersion()
    const kind = fs.existsSync('/etc/debian_version') ? 'deb' : 'rpm'
    const latest = (v, download = 'p.pkg') => ({channel: 'alpha', version: v, downloads: {[kind]: download}})
    const asked = []
    const opened = []
    const showMessageBox = dialog.showMessageBox
    const openExternal = shell.openExternal
    dialog.showMessageBox = async (parent, options) => {
      asked.push(options)
      return {response: 0}
    }
    shell.openExternal = async url => {
      opened.push(url)
    }
    const statePath = path.join(app.getPath('userData'), 'update-check.json')
    const reset = () => {
      asked.length = 0
      opened.length = 0
      fs.rmSync(statePath, {force: true})
    }
    const routes = {}
    const server = await localMirror(routes)
    const base = `http://127.0.0.1:${server.address().port}`
    const mirrors = [base + '/a/', base + '/b/']
    try {
      // the first mirror is down, the second one gives only latest.txt
      routes['/b/alpha/latest.txt'] = latest('9.0.0-alpha')
      routes['/b/alpha/p.pkg'] = 'x'
      reset()
      await updates.check(window, mirrors)
      assert.strictEqual(asked.length, 1, 'нет вопроса')
      assert.strictEqual(opened[0], base + '/b/alpha/p.pkg')

      asked.length = 0
      fs.writeFileSync(statePath, JSON.stringify({asked: '9.0.0-alpha'}))
      await updates.check(window, mirrors)
      assert.strictEqual(asked.length, 0, 'спросили дважды')

      routes['/b/alpha/latest.txt'] = latest(version)
      reset()
      await updates.check(window, mirrors)
      assert.strictEqual(asked.length, 0, 'предложили свою версию')

      routes['/b/alpha/latest.txt'] = latest('9.0.0-alpha', 'http://example.invalid/x.pkg')
      reset()
      await updates.check(window, mirrors)
      assert.strictEqual(asked.length, 0, 'принята чужая ссылка')

      delete routes['/b/alpha/latest.txt']
      reset()
      await updates.check(window, mirrors)
      assert.strictEqual(asked.length, 0, 'вопрос без ответа зеркал')
      assert(!fs.existsSync(statePath), 'без сети проверка считается выполненной')
    } finally {
      server.close()
      dialog.showMessageBox = showMessageBox
      shell.openExternal = openExternal
    }
  }]
]
