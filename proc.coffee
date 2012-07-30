fs = require 'fs'
_  = require 'underscore'

PROCSTAT_FORMAT = "pid comm state ppid pgrp session tty_nr tpgid flags minflt cminflt majflt cmajflt utime stime cutime cstime priority nice num_threads itrealvalue starttime vsize lu rss rsslim startcode endcode startstack kstkesp kstkeip signal blocked sigignore sigcatch wchan nswap cnswap exit_signal processor rt_priority policy delayacct_blkio_ticks guest_time cguest_time".split " "

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
    updateProcErr = err if err
    procCache[pid] || = {}
    procStat = parseProcStat contents
    _.extend procCache[pid], procStat
    
    addChild procStat.ppid, pid
    process.nextTick -> cb()

addChild = (ppid, pid) ->
  procCache[pid].parent = ppid
  procCache[ppid] ||= {}
  procCache[ppid].children ||= []
  procCache[ppid].children.push procCache[pid] 

parseProcStat = (procStat) ->
  ret = {}
  stats = procStat.trim().split " "
  for stat, i in stats
    name = PROCSTAT_FORMAT[i]
    if name
      ret[name] = stat
    else
      console.warn "WARNING: don't know what to do with field #{i}"
  ret

proc = (pid, cb) ->
  [pid, cb] = [null, pid] unless cb?
  updateCache (err, pcache) ->
    if err
      cb err
    else
      cb null, if pid then pcache[pid] else pcache

module.exports = proc
