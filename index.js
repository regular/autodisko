const fs = require('fs')
const hs = require('human-size')
const debug = require('debug')('autodisko')
const {join} = require('path')

module.exports = function(input, output, conf) {
  const {blockdevices} = input
  const disks = (blockdevices || [])
    .filter( ({type}) => type == 'disk')
    .map( tag('too small', ({size}) => size >= 1024 * 1024 * 1024) ) // >= 1 GB
    .map( tag('explicitly ignored', makeIgnoreFilter(conf.ignore_disks)) )
    .map( tag('has partitions', ({children})=>{
      const partitions = (children || []).filter( ({type}) => type == 'part')
      return partitions.length == 0;
    }) )
  
  debug('disks: %O', disks)
  console.log('transport, model, label, name, size, path')
  disks.forEach( ({tran, model, label, name, size, path, tags})=>{
    console.log(`- ${name} ${tran} ${model} ${label || 'n/a'} ${hs(size)} ${path} ${tags ? '(' + tags.join(', ') + ')' : ''}`)
  })
  const candidates = disks.filter( d=>d.tags == undefined || d.tags.length == 0 ).sort( (a,b)=>a.size - b.size)

  // TODO: logic for selecting more complex layouts
  // - raid, hybrid, etc
  const main = candidates[0]
  const template = 'single'
  if (!main) {
    console.error('no candidates')
    process.exit(1)
  }
  console.log(`${main.path} will be used in a single disk layout`)
  copyTemplate(template, {mainDevicePath: main.path}, output)
}

function copyTemplate(name, attrs, output) {
  const let_in = `let\n${Object.entries(attrs).map( ([key, value])=>{
    return `  ${key} = "${value}";`
  })}\nin\n`
  const content = let_in + fs.readFileSync(join(__dirname, 'templates', `${name}.nix`), 'utf8')
  console.error(content)
  fs.writeFileSync(output, content, 'utf8')
}

// -- util
function tag(name, filter) {
  return o=>{
    if (!filter(o)) {
      o.tags = (o.tags || []).concat([name])
    }
    return o
  }
}

function makeIgnoreFilter(opts) {
  if (!opts) return ()=>true

  return o=>{
    return Object.entries(o).every( ([key, value] )=>{
      if (!opts[key]) return true;
      return value !== opts[key]  // do not ignore
    })
  }
}
