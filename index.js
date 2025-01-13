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
  const layouts = [grahamc, single]
  for (const layout of layouts) {
    const result = layout(candidates)
    if (result) {
      const {template, attrs} = result
      copyTemplate(template, attrs, output)
      return
    }
  }
  return new Error('No matching disk layout found.')
}

function grahamc(candidates) {
  if (candidates.length < 2) return
  const first = candidates[0]
  const second = candidates[1]
  if (first.size !== second.size) return

  console.log(`${first.path} and ${second.path} will be used in a zfs mirror (grahamc style)`)
  return {
    template: 'grahamc',
    attrs: {
      mainDevicePath: first.path,
      secondaryDevicePath: second.path
    }
  }
}

function single(candidates) {
  const main = candidates[0]
  if (!main) return
  console.log(`${main.path} will be used in a single disk layout`)
  return {
    template: 'single',
    attrs: {
      mainDevicePath: main.path
    }
  }
}

function copyTemplate(name, attrs, output) {
  const let_in = `let\n${Object.entries(attrs).map( ([key, value])=>{
    return `  ${key} = "${value}";`
  }).join('\n')}\nin\n`
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
