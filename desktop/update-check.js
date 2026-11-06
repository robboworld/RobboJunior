// New version check: latest.json on the file mirrors, the same format as in Robbo Scratch
// (scripts/lib/latest-json.py writes it, scripts/deploy.sh uploads it).
//
//   RobboJunior/latest.json        release channel
//   RobboJunior/alpha/latest.json  alpha channel
//   {channel, version, date, important, notes, downloads: {windows|deb|rpm: <path relative to the file>}}
//
// No network or an unusable answer: nothing is shown. The user is asked once per version and downloads
// the installer in the browser. The User-Agent names the version, OS, architecture and package kind
// (download statistics), no identifiers of the user.

const {app, dialog, shell} = require('electron')
const fs = require('fs')
const http = require('http')
const https = require('https')
const path = require('path')

const MIRRORS = [
  'http://files.robbo.ru/Software/RobboJunior/',
  'https://files.robbo.world/Software/RobboJunior/'
]
const CHANNEL_FILES = {release: 'latest.json', alpha: 'alpha/latest.json'}
const CHECK_INTERVAL_MS = 12 * 60 * 60 * 1000
const START_DELAY_MS = 5000
const REQUEST_TIMEOUT_MS = 15000
const MAX_REDIRECTS = 3
const MAX_NOTE_LINES = 6

const TEXTS = {
  ru: {
    message: 'Доступна новая версия Robbo Junior',
    detail: version => `Версия ${version}. Проекты сохранятся.`,
    download: 'Скачать',
    later: 'Позже'
  },
  en: {
    message: 'A new version of Robbo Junior is available',
    detail: version => `Version ${version}. Your projects will be kept.`,
    download: 'Download',
    later: 'Later'
  }
}

function parseVersion (version) {
  const match = /^(\d+)\.(\d+)\.(\d+)(?:-(.+))?$/.exec(String(version))
  if (!match) return null
  const suffix = match[4] || ''
  // X.Y.Z-N is a rebuild of X.Y.Z and goes after it, X.Y.Z-alpha goes before it
  const stage = suffix === '' ? 1 : (/^\d+$/.test(suffix) ? 2 : 0)
  return {core: [Number(match[1]), Number(match[2]), Number(match[3])], stage, suffix}
}

function compareVersions (a, b) {
  const left = parseVersion(a)
  const right = parseVersion(b)
  if (!left || !right) return (left ? 1 : 0) - (right ? 1 : 0)
  for (let i = 0; i < 3; i++) {
    if (left.core[i] !== right.core[i]) return left.core[i] - right.core[i]
  }
  if (left.stage !== right.stage) return left.stage - right.stage
  if (left.stage === 2) return Number(left.suffix) - Number(right.suffix)
  return left.suffix.localeCompare(right.suffix, 'en', {numeric: true})
}

// Package type the update is downloaded as: Windows installer, or deb / rpm by the Linux distribution
function packageKind () {
  if (process.platform === 'win32') return 'windows'
  try {
    if (fs.existsSync('/etc/debian_version')) return 'deb'
    if (fs.existsSync('/usr/bin/rpm') && !fs.existsSync('/usr/bin/dpkg')) return 'rpm'
    const osRelease = fs.existsSync('/etc/os-release') ? fs.readFileSync('/etc/os-release', 'utf8') : ''
    if (/^ID(_LIKE)?=.*(fedora|rhel|centos|suse|altlinux|alt|redos|rosa)/im.test(osRelease)) return 'rpm'
  } catch (e) {
    // fall through to deb, the most common
  }
  return 'deb'
}

function request (url, method, agent, redirects = 0) {
  return new Promise((resolve, reject) => {
    const lib = url.startsWith('https:') ? https : http
    const req = lib.request(url, {method, timeout: REQUEST_TIMEOUT_MS, headers: {'User-Agent': agent}}, response => {
      const {statusCode, headers} = response
      if (statusCode >= 300 && statusCode < 400 && headers.location && redirects < MAX_REDIRECTS) {
        response.resume()
        resolve(request(new URL(headers.location, url).href, method, agent, redirects + 1))
        return
      }
      if (statusCode !== 200) {
        response.resume()
        reject(new Error(`HTTP ${statusCode}`))
        return
      }
      let body = ''
      response.setEncoding('utf8')
      response.on('data', chunk => {
        body += chunk
      })
      response.on('end', () => resolve(body))
    })
    req.on('timeout', () => req.destroy(new Error('timeout')))
    req.on('error', reject)
    req.end()
  })
}

function readLatest (url, agent) {
  return request(url, 'GET', agent).then(text => {
    const data = JSON.parse(text)
    if (typeof data.version !== 'string' || !data.downloads || typeof data.downloads !== 'object') {
      throw new Error('not a latest.json')
    }
    return data
  })
}

// A mirror whose web server refuses .json is read through latest.txt, the same file
function fetchFromMirror (mirror, file, agent) {
  return readLatest(mirror + file, agent).catch(() => readLatest(mirror + file.replace(/\.json$/, '.txt'), agent))
}

// Download links of a package on every mirror, never outside the mirrors: latest.json comes over plain http
function downloadLinks (relative, file, mirrors) {
  return mirrors.map(mirror => new URL(relative, mirror + file).href)
    .filter((link, i) => link.startsWith(mirrors[i]))
}

function fetchChannel (channel, kind, agent, mirrors) {
  const file = CHANNEL_FILES[channel]
  return mirrors.reduce(
    (previous, mirror) => previous.catch(() => fetchFromMirror(mirror, file, agent)),
    Promise.reject(new Error('no mirror'))
  ).then(data => {
    if (typeof data.downloads[kind] !== 'string') return null
    const links = downloadLinks(data.downloads[kind], file, mirrors)
    return links.length ? {channel, version: data.version, links, notes: data.notes} : null
  }).catch(() => null)
}

// The stable version when there is a newer one, else the alpha
function selectOffer (offers, current) {
  const newer = offers.filter(offer => offer && compareVersions(offer.version, current) > 0)
  return newer.find(offer => offer.channel === 'release') || newer[0] || null
}

// The installer link to open: the first mirror whose file answers
function resolveDownloadUrl (offer, agent) {
  return offer.links.reduce(
    (previous, link) => previous.catch(() => request(link, 'HEAD', agent).then(() => link)),
    Promise.reject(new Error('no mirror'))
  ).catch(() => offer.links[0])
}

function statePath () {
  return path.join(app.getPath('userData'), 'update-check.json')
}

function readState () {
  try {
    return JSON.parse(fs.readFileSync(statePath(), 'utf8'))
  } catch (e) {
    return {}
  }
}

function writeState (state) {
  try {
    fs.writeFileSync(statePath(), JSON.stringify(state))
  } catch (e) {
    // storage unavailable: the check simply runs again next time
  }
}

// The first items of the release message, the same text as in the What's new window
function noteLines (notes, language) {
  const note = notes && notes[language === 'ru' ? 'ru' : 'en']
  if (!note || !note.sections) return ''
  const items = [].concat(note.sections.added || [], note.sections.changed || [], note.sections.fixed || [])
  return items.slice(0, MAX_NOTE_LINES).map(item => `\n• ${item.title}`).join('')
}

function ask (window, offer, agent) {
  const language = app.getLocale().split('-')[0]
  const texts = TEXTS[language] || TEXTS.en
  return dialog.showMessageBox(window, {
    type: 'info',
    message: texts.message,
    detail: texts.detail(offer.version) + noteLines(offer.notes, language),
    buttons: [texts.download, texts.later],
    defaultId: 0,
    cancelId: 1
  }).then(({response}) => {
    if (response !== 0) return null
    return resolveDownloadUrl(offer, agent).then(url => shell.openExternal(url))
  })
}

function check (window, mirrors = MIRRORS) {
  const state = readState()
  if (state.checkedAt && Date.now() - state.checkedAt < CHECK_INTERVAL_MS) return Promise.resolve()

  const kind = packageKind()
  const current = app.getVersion()
  const agent = `RobboJunior/${current} (${process.platform}; ${process.arch}; ${kind})`
  const channels = Object.keys(CHANNEL_FILES)

  return Promise.all(channels.map(channel => fetchChannel(channel, kind, agent, mirrors))).then(offers => {
    if (!offers.some(Boolean)) return null // offline: try again at the next start
    const offer = selectOffer(offers, current)
    const asked = offer && state.asked === offer.version
    writeState(Object.assign(state, {checkedAt: Date.now()}, offer ? {asked: offer.version} : {}))
    if (!offer || asked || window.isDestroyed()) return null
    return ask(window, offer, agent)
  }).catch(error => console.log('[update-check] ' + error.message))
}

function start (window) {
  window.webContents.once('did-finish-load', () => {
    setTimeout(() => {
      if (!window.isDestroyed()) check(window)
    }, START_DELAY_MS)
  })
}

module.exports = {start, check, compareVersions, selectOffer, downloadLinks}
