require 'colors'
exec = require('child_process').exec
fs = require 'fs'

args = process.argv.slice 2

for arg in args
  unless arg in ['git', 'bower', 'npm', 'status']
    console.error """
    
       Usage: #{'enhance'.cyan} [<types>]
    
       Types:
       
         git       #{'git pull'.blue}
         npm       #{'npm update --production'.blue}
         bower     #{'bower update'.blue}
         status    #{'git status -s --porcelain'.blue}
       
    """
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

gitpull = (dir, cb) -> cmd "cd #{dir} && git pull", cb
trygit = (dir, cb) ->
  fs.exists "#{dir}/.git", (isthere) ->
    return cb() if !isthere
    series [
      (cb) -> gitpull dir, cb
    ], ->
      console.log "   #{'git\'d'.blue}      #{dir}"
      cb()

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
trygitstatus = (dir, cb) ->
  fs.exists "#{dir}/.git", (isthere) ->
    return cb() if !isthere
    series [
      (cb) -> gitstatus dir, (status) ->
        console.log "   #{dir.blue}"
        return cb() if !status? or status is ''
        groups = {}
        for line in status.split '\n'
          code = line.substr 0, 2
          continue if code is ''
          groups[code] = 0 if !groups[code]?
          groups[code]++
        result = for type, count of groups
          if gitmeaning[type]?
            "#{count} #{gitmeaning[type]}"
          else
            "#{type}:#{count}"
        console.log "   #{result.join ' '}"
        cb()
    ], ->
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
  if args.length is 0 or 'git' in args
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
if 'status' in args and args.length isnt 1
  console.error """
  
     Usage: #{'enhance'.cyan} [<types>]
  
     Types:
     
       git       #{'git pull'.blue}
       npm       #{'npm update --production'.blue}
       bower     #{'bower update'.blue}
       status    #{'git status -s --porcelain'.blue}
     
  """
  process.exit 1

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
