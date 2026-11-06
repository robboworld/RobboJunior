// Robot.js alone, with a fake HTTP layer: timing of power commands that the app scenarios cannot see.

const assert = require('assert')
const fs = require('fs')

const source = fs.readFileSync(process.argv[2], 'utf8')
  .replace(/^import .*$/gm, '')
  .replace('export default class Robot', 'class Robot')
const sent = []
global.XMLHttpRequest = class {
  open (method, url) {
    sent.push(url.split('rob_power/')[1])
  }
  send () {}
}
const Prims = {
  DoNextBlock (strip) {
    strip.nexts = (strip.nexts || 0) + 1
  }
}
const Robot = new Function('Prims', 'isTablet', 'isAndroid', source + ';return Robot')(Prims, false, false)
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))
const strip = (steps, version = 0) => ({robot_version: version, thisblock: {getArgValue: () => steps}})

async function main () {
  Robot.init()

  const finished = strip(2)
  Robot.Robot_forward(finished)
  await sleep(650)
  assert.strictEqual(sent[0], '13/13')
  assert.strictEqual(sent.at(-1), '00/00')
  assert.strictEqual(finished.nexts, 1)

  sent.length = 0
  const stopped = strip(10)
  Robot.Robot_back(stopped)
  await sleep(250)
  Robot.cancel(stopped)
  const count = sent.length
  await sleep(450)
  assert.strictEqual(sent.length, count, 'команды после остановки')
  assert.strictEqual(sent[0], '53/53')
  assert.strictEqual(sent.at(-1), '00/00')
  assert.strictEqual(stopped.nexts, undefined, 'остановленный поток пошёл дальше')

  sent.length = 0
  const long = strip(5)
  const short = strip(1, 3)
  Robot.Robot_left(long)
  await sleep(50)
  Robot.Robot_right(short)
  await sleep(600)
  assert(sent.includes('3f/7f'), 'второй скрипт не ведёт робота')
  assert(!sent.includes('00/00'), 'короткий блок остановил длинный')
  assert.strictEqual(sent.at(-1), '53/13', 'первый скрипт не продолжил')
  Robot.cancel(long)
  assert.strictEqual(sent.at(-1), '00/00')

  sent.length = 0
  const driving = strip(50)
  const stopBlock = strip(0)
  Robot.Robot_forward(driving)
  await sleep(30)
  Robot.Robot_stop(stopBlock)
  const after = sent.length
  await sleep(300)
  assert.strictEqual(sent.length, after, 'команды после блока стоп')
  assert.strictEqual(driving.nexts, 1)
  assert.strictEqual(stopBlock.nexts, 1)
  assert.strictEqual(Robot.robot.drivers.length, 0)
  console.log('ок')
}

main().catch(error => {
  console.error(error.message, sent)
  process.exit(1)
})
