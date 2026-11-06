// Every interface string exists in every language, and the real library is translated into Russian.
// CHARACTER_ and BACKGROUND_ keys in en.json are upstream's and do not match our media.json.

const path = require('path')

const appDir = process.argv[2]
const load = name => require(path.join(appDir, name))
const LIBRARY_KEY = /^(CHARACTER|BACKGROUND)_/
const en = load('localizations/en.json')
const ru = load('localizations/ru.json')
const media = load('media.json')
const problems = []

const keys = Object.keys(en).filter(key => !LIBRARY_KEY.test(key))
for (const locale of Object.values(load('settings.json').supportedLocales)) {
  const messages = load(`localizations/${/^(zh|pt)/.test(locale) ? locale : locale.split('-')[0]}.json`)
  const missing = keys.filter(key => !(key in messages))
  if (missing.length) problems.push(`${locale}: нет ${missing.slice(0, 5).join(', ')}`)
}

// The program is called Robbo Junior everywhere; only the page about its origin names ScratchJr
for (const locale of Object.values(load('settings.json').supportedLocales)) {
  const messages = load(`localizations/${/^(zh|pt)/.test(locale) ? locale : locale.split('-')[0]}.json`)
  const old = Object.keys(messages).filter(key => key !== 'ABOUT_BASED_ON_DESCRIPTION' && /ScratchJr/.test(messages[key]))
  if (old.length) problems.push(`${locale}: ScratchJr в ${old.slice(0, 5).join(', ')}`)
}

const missingNames = [].concat(
  media.sprites.map(item => 'CHARACTER_' + item.md5),
  media.backgrounds.filter(item => item.md5 !== 'separator').map(item => 'BACKGROUND_' + item.md5)
).filter(key => !(key in ru))
if (missingNames.length) problems.push(`ru: нет ${missingNames.slice(0, 5).join(', ')} и других, всего ${missingNames.length}`)

if (problems.length) {
  console.error(problems.join('\n'))
  process.exit(1)
}
console.log(`ок: ${keys.length} строк, ${media.sprites.length + media.backgrounds.length - 1} названий библиотеки`)
