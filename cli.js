const fs = require('fs')

const conf = require('rc')('autodisko')
const debug = require('debug')('autodisko')

const doit = require('.')

async function main() {
  const [filename, outfilename] = conf._;
  debug('conf: %O', conf)
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
