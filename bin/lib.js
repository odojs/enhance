// Generated by CoffeeScript 1.7.1
(function() {
  var bowerinstall, bowerupdate, cmd, exec, exists, gitpull, npmupdate, parallel, recordstderr, series, trybower, trydirectory, trygit, trynpm, _stderr;

  require('colors');

  exec = require('child_process').exec;

  exists = require('fs').exists;

  _stderr = [];

  recordstderr = function(stderr) {
    return _stderr.push(stderr);
  };

  series = function(tasks, callback) {
    var next, result;
    tasks = tasks.slice(0);
    next = function(cb) {
      var task;
      if (tasks.length === 0) {
        return cb();
      }
      task = tasks.shift();
      return task(function() {
        return next(cb);
      });
    };
    result = function(cb) {
      return next(cb);
    };
    if (callback != null) {
      result(callback);
    }
    return result;
  };

  parallel = function(tasks, callback) {
    var count, result;
    count = tasks.length;
    result = function(cb) {
      var task, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = tasks.length; _i < _len; _i++) {
        task = tasks[_i];
        _results.push(task(function() {
          count--;
          if (count === 0) {
            return cb();
          }
        }));
      }
      return _results;
    };
    if (callback != null) {
      result(callback);
    }
    return result;
  };

  cmd = function(cmd, cb) {
    return exec(cmd, function(err, stdout, stderr) {
      if (err != null) {
        throw err;
      }
      if ((stderr != null) && stderr !== '') {
        recordstderr(stderr);
      }
      return cb();
    });
  };

  gitpull = function(dir, cb) {
    return cmd("cd " + dir + " && git pull", cb);
  };

  trygit = function(dir, cb) {
    return exists("" + dir + "/.git", function(isthere) {
      if (!isthere) {
        return cb();
      }
      return series([
        function(cb) {
          return gitpull(dir, cb);
        }
      ], function() {
        console.log("   " + 'git\'d'.blue + "      " + dir);
        return cb();
      });
    });
  };

  npmupdate = function(dir, cb) {
    return cmd("cd " + dir + " && npm update --production", function() {
      console.log("   " + 'npm\'d'.magenta + "      " + dir);
      return cb();
    });
  };

  trynpm = function(dir, cb) {
    return exists("" + dir + "/package.json", function(isthere) {
      if (!isthere) {
        return cb();
      }
      return npmupdate(dir, cb);
    });
  };

  bowerinstall = function(dir, cb) {
    return cmd("cd " + dir + " && bower install", cb);
  };

  bowerupdate = function(dir, cb) {
    return cmd("cd " + dir + " && bower update", function() {
      console.log("   " + 'bower\'d'.green + "    " + dir);
      return cb();
    });
  };

  trybower = function(dir, cb) {
    return exists("" + dir + "/bower.json", function(isthere) {
      if (!isthere) {
        return cb();
      }
      return series([
        function(cb) {
          return bowerinstall(dir, cb);
        }, function(cb) {
          return bowerupdate(dir, cb);
        }
      ], cb);
    });
  };

  trydirectory = function(dir, cb) {
    return series([
      function(cb) {
        return trygit(dir, cb);
      }, function(cb) {
        return parallel([
          function(cb) {
            return trynpm(dir, cb);
          }, function(cb) {
            return trynpm("" + dir + "/web", cb);
          }, function(cb) {
            return trybower(dir, cb);
          }, function(cb) {
            return trybower("" + dir + "/web", cb);
          }
        ], cb);
      }
    ], cb);
  };

  console.log();

  parallel([
    function(cb) {
      return trydirectory('identity-management', cb);
    }, function(cb) {
      return trydirectory('user-management', cb);
    }, function(cb) {
      return trydirectory('under-keel-clearance', cb);
    }, function(cb) {
      return trydirectory('forecasting', cb);
    }, function(cb) {
      return trydirectory('berth-safety-forecast', cb);
    }, function(cb) {
      return trydirectory('ui-assets', cb);
    }
  ], function() {
    console.log();
    if (_stderr.length !== 0) {
      console.log('   fin with warnings.'.red);
    } else {
      console.log('   fin.'.cyan);
    }
    return console.log();
  });

}).call(this);