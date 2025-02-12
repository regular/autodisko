const fs = require('fs')

const conf = require('rc')('autodisko')
const debug = require('debug')('autodisko')

const doit = require('.')

async function main() {
  debug('conf: %O', conf)

  if (conf._.length < 1) {
    console.error(`Usage: inputfile [--output outputfile | --candidates]`)
    process.exit(1)
  }
  const filename = conf._[0];
  const outfilename = conf.output

  debug('input filename: %s', filename)
  debug('output filename: %s', outfilename)

  let input;
  try {
    input = JSON.parse(fs.readFileSync(filename))
  } catch(err) {
    console.error(err)
    process.exit(1)
  }

  const err = await doit(input, outfilename, conf)
  if (err) {
    console.error(err.message)
    process.exit(1)
  }
}

main()
