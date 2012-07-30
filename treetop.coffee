proc = require './proc'

INTERVAL = 3

diff = null
use = {}
old = {}

printProc = (proc, indent='') ->
  pid = proc.pid
  use[pid] = parseInt(proc.utime) + parseInt(proc.stime)
  diff = use[pid] - old[pid] if old[pid] != null
  old[pid] = use[pid]

  console.log indent, proc.comm, Math.round(diff/INTERVAL)
  if proc.children
    printProc child, indent+'  ' for child in proc.children


setInterval ->
  proc (err, procs) ->
    process.stdout.write '\u001B[2J\u001B[0;0f'
    printProc procs[1]
, INTERVAL*1000
