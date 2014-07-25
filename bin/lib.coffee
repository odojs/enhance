require 'colors'
exec = require('child_process').exec
fs = require 'fs'

args = process.argv.slice 2

usage = """

      Usage: #{'enhance'.cyan} [<commands>]
      
      Default commands: (these run if no commands are specified)
   
         pull      #{'git pull'.blue}
         npm       #{'npm update --production'.blue}
         bower     #{'bower update'.blue}
    
      Optional commands:
   
         push      #{'git push'.blue}
         status    #{'git fetch'.blue}
                   #{'git status -s --porcelain'.blue}
                   #{'git diff --stat origin/master HEAD'.blue}
                   #{'git diff --stat ...origin'.blue}
   
"""

for arg in args
  unless arg in ['pull', 'push', 'bower', 'npm', 'status']
    console.error usage
    process.exit 1

if 'status' in args and args.length isnt 1
  console.error usage
  process.exit 1

_stderr = []
recordstderr = (stderr) ->
  _stderr.push stderr

series = (tasks, callback) ->
  tasks = tasks.slice 0
  next = (cb) ->
    return cb() if tasks.length is 0
    task = tasks.shift()
    task -> next cb
  result = (cb) -> next cb
  result(callback) if callback?
  result

parallel = (tasks, callback) ->
  count = tasks.length
  result = (cb) ->
    return cb() if count is 0
    for task in tasks
      task ->
        count--
        cb() if count is 0
  result(callback) if callback?
  result

cmd = (cmd, cb) ->
  #console.log cmd
  exec cmd, (err, stdout, stderr) ->
    if err?
      console.error "Issue running #{cmd}"
      throw err
    recordstderr stderr if stderr? and stderr isnt ''
    cb stdout

gitpull = (dir, cb) -> exec  "cd #{dir} && git pull", (err, stdout, stderr) ->
  if err?
    console.log "   Can't #{'pull'.blue} #{dir}"
  else
    console.log "   #{'pull\'d'.blue}     #{dir}"
  return cb()

gitpush = (dir, cb) -> exec  "cd #{dir} && git push", (err, stdout, stderr) ->
  if err?
    console.log "   Can't #{'push'.blue} #{dir}"
  else
    console.log "   #{'push\'d'.blue}     #{dir}"
  return cb()
  
trygit = (dir, cb) ->
  fs.exists "#{dir}/.git", (isthere) ->
    return cb() if !isthere
    tasks = []
    if args.length is 0 or 'pull' in args
      tasks.push (cb) -> gitpull dir, cb
    if 'push' in args
      tasks.push (cb) -> gitpush dir, cb
    series tasks, cb

gitmeaning =
  ' M': 'modified'
  ' A': 'added'
  ' D': 'deleted'
  ' R': 'renamed'
  ' C': 'copied'
  '??': 'untracked'
  '!!': 'ignored'

gitstatus = (dir, cb) ->
  cmd "cd #{dir} && git status -s --porcelain", cb
gitfetch = (dir, cb) ->
  cmd "cd #{dir} && git fetch", cb
gittopush = (dir, cb) ->
  cmd "cd #{dir} && git symbolic-ref --short -q HEAD", (branch) ->
    cmd "cd #{dir} && git diff --stat origin/#{branch.trim()} HEAD", cb
gittopull = (dir, cb) ->
  cmd "cd #{dir} && git diff --stat ...origin", cb
trygitstatus = (dir, cb) ->
  fs.exists "#{dir}/.git", (isthere) ->
    return cb() if !isthere
    results = []
    series [
      (cb) -> gitfetch dir, cb
      (cb) -> gitstatus dir, (status) ->
        return cb() if !status? or status is ''
        lines = status.split '\n'
        groups = {}
        for line in lines
          code = line.substr 0, 2
          continue if code is ''
          groups[code] = 0 if !groups[code]?
          groups[code]++
        result = for type, count of groups
          if gitmeaning[type]?
            "#{count} #{gitmeaning[type]}"
          else
            "#{type}:#{count}"
        results.push "   #{'local:'.magenta}    #{lines.length} files changed, #{result.join ' '}"
        cb()
      (cb) -> gittopush dir, (status) ->
        return cb() if !status? or status is ''
        status = status.split('\n')
        status.pop()
        status = status.pop()
        results.push "   #{'to push:'.magenta}  #{status.trim()}"
        cb()
      (cb) -> gittopull dir, (status) ->
        return cb() if !status? or status is ''
        status = status.split('\n')
        status.pop()
        status = status.pop()
        results.push "   #{'to pull:'.magenta}  #{status}"
        cb()
    ], ->
      if results.length is 0
        console.log " #{'√'.green} #{dir.blue}"
      else
        console.log " #{'X'.red} #{dir.red} has changes"
        console.log results.join '\n'
      cb()

npmupdate = (dir, cb) -> cmd "cd #{dir} && npm update --production", ->
  console.log "   #{'npm\'d'.magenta}      #{dir}"
  cb()
trynpm = (dir, cb) ->
  fs.exists "#{dir}/package.json", (isthere) ->
    return cb() if !isthere
    npmupdate dir, cb

bowerinstall = (dir, cb) -> cmd "cd #{dir} && bower install", cb
bowerupdate = (dir, cb) -> cmd "cd #{dir} && bower update", ->
  console.log "   #{'bower\'d'.green}    #{dir}"
  cb()
trybower = (dir, cb) ->
  fs.exists "#{dir}/bower.json", (isthere) ->
    return cb() if !isthere
    series [
      (cb) -> bowerinstall dir, cb
      (cb) -> bowerupdate dir, cb
    ], cb

trydirectory = (dir, cb) ->
  tasks = []
  if args.length is 0 or 'push' in args or 'pull' in args
    tasks.push (cb) -> trygit dir, cb
  if 'status' in args
    tasks.push (cb) -> trygitstatus dir, cb
    
  next = []
  if args.length is 0 or 'npm' in args
    next.push (cb) -> trynpm dir, cb
    next.push (cb) -> trynpm "#{dir}/web", cb
  
  if args.length is 0 or 'bower' in args
    next.push (cb) -> trybower dir, cb
    next.push (cb) -> trybower "#{dir}/web", cb
  
  tasks.push (cb) -> parallel next, cb
  
  series tasks, cb

fin =  ->
  #for stderr in _stderr
  # console.error stderr
  console.log()
  if _stderr.length isnt 0
    console.log '   fin with warnings.'.red
  else
    console.log '   fin.'.cyan
  console.log()

console.log()

trydirectory '.', ->
  fs.readdir '.', (err, files) ->
    throw err if err?
    tasks = []
    for file in files
      do (file) ->
        tasks.push (cb) ->
          fs.stat file, (err, stat) ->
            throw err if err?
            return cb() if !stat.isDirectory()
            trydirectory file, cb
    
    parallel tasks, fin
