const fs = require('fs')
const {join} = require('path')
const test = require('tape')
const ad = require('..')

test('ignore disk by name', t=>{
  const result = ad(JSON.parse(fs.readFileSync(join(__dirname, 'fixtures', 'fixture1.json'))), {
    ignore_disks: {
      name: 'nvme0n1'
    }
  })
  console.log(result)
  t.end()
})
