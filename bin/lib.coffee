require 'colors'
exec = require('child_process').exec
exists = require('fs').exists

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
		for task in tasks
			task ->
				count--
				cb() if count is 0
	result(callback) if callback?
	result

cmd = (cmd, cb) ->
	exec cmd, (err, stdout, stderr) ->
		throw err if err?
		recordstderr stderr if stderr? and stderr isnt ''
		cb()

gitpull = (dir, cb) -> cmd "cd #{dir} && git pull", cb
trygit = (dir, cb) ->
	exists "#{dir}/.git", (isthere) ->
		return cb() if !isthere
		series [
			(cb) -> gitpull dir, cb
		], ->
			console.log "   #{'git\'d'.blue}      #{dir}"
			cb()

npmupdate = (dir, cb) -> cmd "cd #{dir} && npm update --production", ->
	console.log "   #{'npm\'d'.magenta}      #{dir}"
	cb()
trynpm = (dir, cb) ->
	exists "#{dir}/package.json", (isthere) ->
		if !isthere
			return cb()
		npmupdate dir, cb

bowerinstall = (dir, cb) -> cmd "cd #{dir} && bower install", cb
bowerupdate = (dir, cb) -> cmd "cd #{dir} && bower update", ->
	console.log "   #{'bower\'d'.green}    #{dir}"
	cb()
trybower = (dir, cb) ->
	exists "#{dir}/bower.json", (isthere) ->
		return cb() if !isthere
		series [
			(cb) -> bowerinstall dir, cb
			(cb) -> bowerupdate dir, cb
		], cb

trydirectory = (dir, cb) ->
	series [
		(cb) -> trygit dir, cb
		(cb) -> parallel [
			(cb) -> trynpm dir, cb
			(cb) -> trynpm "#{dir}/web", cb
			(cb) -> trybower dir, cb
			(cb) -> trybower "#{dir}/web", cb
		], cb
	], cb

console.log()
parallel [
	(cb) -> trydirectory 'identity-management', cb
	(cb) -> trydirectory 'user-management', cb
	(cb) -> trydirectory 'under-keel-clearance', cb
	(cb) -> trydirectory 'forecasting', cb
	(cb) -> trydirectory 'berth-safety-forecast', cb
	(cb) -> trydirectory 'ui-assets', cb
], ->
	#for stderr in _stderr
	#	console.error stderr
	console.log()
	if _stderr.length isnt 0
		console.log '   fin with warnings.'.red
	else
		console.log '   fin.'.cyan
	console.log()
