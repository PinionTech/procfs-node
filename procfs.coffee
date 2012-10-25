fs   = require 'fs'
lazy = require 'lazy'
_    = require 'underscore'

qw = (str) -> str.split ' '

FORMATS =
  pidstat: qw "pid comm state ppid pgrp session tty_nr tpgid flags minflt cminflt majflt cmajflt utime stime cutime cstime priority nice num_threads itrealvalue starttime vsize lu rss rsslim startcode endcode startstack kstkesp kstkeip signal blocked sigignore sigcatch wchan nswap cnswap exit_signal processor rt_priority policy delayacct_blkio_ticks guest_time cguest_time"
  diskstats: qw "dev_major dev_minor name reads reads_merged read_sectors read_time writes writes_merged write_sectors write_time ios_in_progress ios_time ios_time_weighted"
  stat:
    cpu: qw "name user nice system idle iowait irq softirq steal guest guest_nice"
  partitions: qw "major minor blocks name"
  mounts: qw "device mountpoint type options freq pass"

procCache = null
updating = false
onUpdate = []

returnUpdate = (err, result) ->
  updating = false
  cb err, result for cb in onUpdate
  onUpdate = []
  
  unless err
    process.nextTick ->
      procCache = null
  

numeric = /^\d+$/

updateCache = (cb) ->
  return onUpdate.push cb if updating
  return cb(null, procCache) if procCache
  

  #console.log "updating cache"
  updating = true
  procCache = {}
  onUpdate.push cb

  fs.readdir '/proc', (err, files) ->
    return returnUpdate err if err

    done = null
    count = 0

    updateProcErr = false

    for file in files
      do (file) ->
        if file.match numeric
          count++
          process.nextTick -> updateProc file, done

    #console.log "count is", count
    done = _.after count, ->
      return returnUpdate updateProcErr if updateProcErr
      returnUpdate null, procCache

nc = 0
updateProcErr = false
updateProc = (pid, cb) ->
  #console.log "updateProc", pid, cb?, ++nc
  fs.readFile "/proc/#{pid}/stat", 'utf8', (err, contents) ->
    return cb updateProcErr = err if err
    procCache[pid] || = {}
    stats = contents.trim().split /\s+/
    procStat = format FORMATS.pidstat, stats
    _.extend procCache[pid], procStat
    
    addChild procStat.ppid, pid
    process.nextTick -> cb()

addChild = (ppid, pid) ->
  procCache[pid].parent = ppid
  procCache[ppid] ||= {}
  procCache[ppid].children ||= []
  procCache[ppid].children.push procCache[pid] 

maybeNum = (val) ->
  num = parseInt val
  if !isNaN num
    return num
  else
    return val

format = (formatter, data) ->
  ret = {}
  for val, i in data
    name = formatter[i]
    if name
      ret[name] = maybeNum val
    else
      console.warn "WARNING: don't know what to do with field #{i}: #{val}"   
  ret

proc = (pid, cb) ->
  [pid, cb] = [null, pid] unless cb?
  updateCache (err, pcache) ->
    if err
      cb err
    else
      cb null, if pid then pcache[pid] else pcache

procParser = (file, fn) -> (cb=->) ->
  ret = {}
  stream = lazy fs.createReadStream file
  stream.lines.forEach (line) -> fn ret, line.toString('utf8').trim()

  stream.on 'error', (err) ->
    cb err

  stream.on 'end', ->
    cb null, ret

stat = procParser '/proc/stat', (ret, line) ->
  line = line.split /\s+/
  name = line[0]
  if name.match /^cpu/
    ret.cpus ?= 0
    ret.cpus++ unless name is 'cpu'
    ret[name] = format FORMATS.stat.cpu, line
  else if line.length is 2
    ret[name] = maybeNum line[1]

diskstats = procParser '/proc/diskstats', (ret, line) ->
  line = line.split /\s+/
  name = line[2]
  ret[name] = format FORMATS.diskstats, line

vmstat = procParser '/proc/vmstat', (ret, line) ->
  line = line.split /\s+/
  [k, v] = line
  ret[k] = maybeNum v

meminfo = procParser '/proc/meminfo', (ret, line) ->
  line = line.split ':'
  [k, v] = line
  ret[k] = maybeNum v

partitions = procParser '/proc/partitions', (ret, line) ->
  line = line.split /\s+/
  name = line[3]
  return if !name or line[0] is 'major'
  ret[name] = format FORMATS.partitions, line

mounts = procParser '/proc/mounts', (ret, line) ->
  line = line.split /\s+/
  name = line[1]
  ret[name] = format FORMATS.mounts, line


proc[k] = v for k, v of {stat, diskstats, vmstat, meminfo, partitions, mounts}

module.exports = proc
