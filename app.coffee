connect = require 'connect'
fs = require 'fs'
sys = require 'sys'
exec = require('child_process').exec

ALLOW_NETWORKS = [
	# GitHub WebHook public IPs
	'204.232.175.64/27'
	'192.30.252.0/22'
]

PUBLIC_DIR = __dirname + '/public'

handleRepository = (owner, repo, url) ->
	exec """
		mkdir -p #{PUBLIC_DIR}/#{owner}/#{repo}
		cd #{PUBLIC_DIR}/#{owner}/#{repo}
		if [ -d ".git" ]; then
			git fetch #{url} gh-pages
		else
			git init
			git fetch #{url} gh-pages:gh-pages
			git checkout gh-pages
		fi
	""", (err, stdout, stderr) ->
		console.log 'ToDo'

app = connect()
app.use connect.logger 'dev'
app.use connect.static PUBLIC_DIR
app.use connect.bodyParser()
app.use (req, res, next) ->
	if req.body.payload
		try
			payload = JSON.parse req.body.payload
			res.end()
			r = payload.repository
			handleRepository r.owner.name, r.name, r.url
		catch e
			next e
	else next()
app.listen process.env.PORT or 3000