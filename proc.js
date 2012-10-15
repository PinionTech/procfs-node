// Generated by CoffeeScript 1.3.3
(function() {
  var FORMATS, addChild, diskstats, format, fs, lazy, maybeNum, nc, numeric, onUpdate, proc, procCache, qw, returnUpdate, stat, updateCache, updateProc, updateProcErr, updating, vmstat, _;

  fs = require('fs');

  lazy = require('lazy');

  _ = require('underscore');

  qw = function(str) {
    return str.split(' ');
  };

  FORMATS = {
    pidstat: qw("pid comm state ppid pgrp session tty_nr tpgid flags minflt cminflt majflt cmajflt utime stime cutime cstime priority nice num_threads itrealvalue starttime vsize lu rss rsslim startcode endcode startstack kstkesp kstkeip signal blocked sigignore sigcatch wchan nswap cnswap exit_signal processor rt_priority policy delayacct_blkio_ticks guest_time cguest_time"),
    diskstats: qw("dev_major dev_minor name reads reads_merged read_sectors read_time writes writes_merged write_sectors write_time ios_in_progress ios_time ios_time_weighted"),
    stat: {
      cpu: qw("name user nice system idle iowait irq softirq steal guest guest_nice")
    }
  };

  procCache = null;

  updating = false;

  onUpdate = [];

  returnUpdate = function(err, result) {
    var cb, _i, _len;
    updating = false;
    for (_i = 0, _len = onUpdate.length; _i < _len; _i++) {
      cb = onUpdate[_i];
      cb(err, result);
    }
    onUpdate = [];
    if (!err) {
      return process.nextTick(function() {
        return procCache = null;
      });
    }
  };

  numeric = /^\d+$/;

  updateCache = function(cb) {
    if (updating) {
      return onUpdate.push(cb);
    }
    if (procCache) {
      return cb(null, procCache);
    }
    updating = true;
    procCache = {};
    onUpdate.push(cb);
    return fs.readdir('/proc', function(err, files) {
      var count, done, file, updateProcErr, _fn, _i, _len;
      if (err) {
        return returnUpdate(err);
      }
      done = null;
      count = 0;
      updateProcErr = false;
      _fn = function(file) {
        if (file.match(numeric)) {
          count++;
          return process.nextTick(function() {
            return updateProc(file, done);
          });
        }
      };
      for (_i = 0, _len = files.length; _i < _len; _i++) {
        file = files[_i];
        _fn(file);
      }
      return done = _.after(count, function() {
        if (updateProcErr) {
          return returnUpdate(updateProcErr);
        }
        return returnUpdate(null, procCache);
      });
    });
  };

  nc = 0;

  updateProcErr = false;

  updateProc = function(pid, cb) {
    return fs.readFile("/proc/" + pid + "/stat", 'utf8', function(err, contents) {
      var procStat, stats;
      if (err) {
        return cb(updateProcErr = err);
      }
      procCache[pid] || (procCache[pid] = {});
      stats = contents.trim().split(/\s+/);
      procStat = format(FORMATS.pidstat, stats);
      _.extend(procCache[pid], procStat);
      addChild(procStat.ppid, pid);
      return process.nextTick(function() {
        return cb();
      });
    });
  };

  addChild = function(ppid, pid) {
    var _base;
    procCache[pid].parent = ppid;
    procCache[ppid] || (procCache[ppid] = {});
    (_base = procCache[ppid]).children || (_base.children = []);
    return procCache[ppid].children.push(procCache[pid]);
  };

  maybeNum = function(val) {
    var num;
    num = parseInt(val);
    if (!isNaN(num)) {
      return num;
    } else {
      return val;
    }
  };

  format = function(formatter, data) {
    var i, name, ret, val, _i, _len;
    ret = {};
    for (i = _i = 0, _len = data.length; _i < _len; i = ++_i) {
      val = data[i];
      name = formatter[i];
      if (name) {
        ret[name] = maybeNum(val);
      } else {
        console.warn("WARNING: don't know what to do with field " + i + ": " + val);
      }
    }
    return ret;
  };

  proc = function(pid, cb) {
    var _ref;
    if (cb == null) {
      _ref = [null, pid], pid = _ref[0], cb = _ref[1];
    }
    return updateCache(function(err, pcache) {
      if (err) {
        return cb(err);
      } else {
        return cb(null, pid ? pcache[pid] : pcache);
      }
    });
  };

  stat = function(cb) {
    var ret, stream;
    if (cb == null) {
      cb = function() {};
    }
    ret = {};
    ret.cpus = 0;
    stream = lazy(fs.createReadStream('/proc/stat'));
    stream.lines.forEach(function(line) {
      var name;
      line = line.toString('utf8').split(/\s+/);
      name = line[0];
      if (name.match(/^cpu/)) {
        if (name !== 'cpu') {
          ret.cpus++;
        }
        return ret[name] = format(FORMATS.stat.cpu, line);
      } else if (line.length === 2) {
        return ret[name] = maybeNum(line[1]);
      }
    });
    stream.on('error', function(err) {
      return cb(err);
    });
    return stream.on('end', function() {
      return cb(null, ret);
    });
  };

  diskstats = function(cb) {
    var ret, stream;
    if (cb == null) {
      cb = function() {};
    }
    ret = {};
    stream = lazy(fs.createReadStream('/proc/diskstats'));
    stream.lines.forEach(function(line) {
      var name;
      line = line.toString('utf8').trim().split(/\s+/);
      name = line[2];
      return ret[name] = format(FORMATS.diskstats, line);
    });
    stream.on('error', function(err) {
      return cb(err);
    });
    return stream.on('end', function() {
      return cb(null, ret);
    });
  };

  vmstat = function(cb) {
    var ret, stream;
    if (cb == null) {
      cb = function() {};
    }
    ret = {};
    stream = lazy(fs.createReadStream('/proc/vmstat'));
    stream.lines.forEach(function(line) {
      var k, v;
      line = line.toString('utf8').trim().split(/\s+/);
      k = line[0], v = line[1];
      return ret[k] = maybeNum(v);
    });
    stream.on('error', function(err) {
      return cb(err);
    });
    return stream.on('end', function() {
      return cb(null, ret);
    });
  };

  proc.stat = stat;

  proc.diskstats = diskstats;

  proc.vmstat = vmstat;

  module.exports = proc;

}).call(this);
