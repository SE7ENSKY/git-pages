connect = require 'connect'
fs = require 'fs'
sys = require 'sys'
exec = require('child_process').exec

# not used yet
ALLOW_NETWORKS = [
	# GitHub WebHook public IPs
	'204.232.175.64/27'
	'192.30.252.0/22'
]

PORT = process.env.PORT or 3000
PUBLIC_DIR = process.env.PUBLIC_DIR or "#{__dirname}/public"
ROOT_HOST = process.env.ROOT_HOST or "localhost"
rootHostRegexed = ROOT_HOST.replace ///\.///g, '\\.'

cnames = {}
redirectHosts = {}
targets = ['se7ensky/matescript.com']

serviceHookEndpoint = (req, res, next) ->
	if req.method is 'POST' and req.body.payload
		try
			# ToDo: validate input
			payload = JSON.parse req.body.payload
			res.end()
			r = payload.repository
			handleRepository r.owner.name, r.name, r.url
		catch e
			next e
	else next()

vhostRewriter = (req, res, next) ->
	if host = req.headers.host
		host = host.replace ///\:\d+$///, ''
		if redirectHost = redirectHosts[host]
			res.writeHead 301, Location: "http://#{redirectHost}/"
			res.end()
		else
			target = if cname = cnames[host]
				cnames[host]
			else if m = host.match new RegExp "^([a-zA-Z0-9\\-\\.]+)\\.([a-zA-Z0-9\\-]+)\\.#{rootHostRegexed}$"
				"#{m[2]}/#{m[1]}"
			else null

			req.url = "/#{target}#{req.url}" if target
			next()
	else next()

handleRepository = (owner, repo, url) ->
	owner = owner.toLowerCase()
	repo = repo.toLowerCase()
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
		readConfig "#{owner}/#{repo}"
		console.log "Successfully handled #{owner}/#{repo} from #{url}"

readConfig = (target) ->
	dir = "#{PUBLIC_DIR}/#{target}"
	if fs.existsSync "#{dir}/CNAME"
		cname = fs.readFileSync "#{dir}/CNAME"
		cname = "#{cname}".replace ///\s///g, ''
		cnames[cname] = target
		m = target.split '/'
		hostPart = "#{m[1]}.#{m[0]}"
		redirectHosts["#{hostPart}.#{ROOT_HOST}"] = cname
		if m = cname.match ///^www\.(.+)$///
			tld = m[1]
			redirectHosts[tld] = cname
		else
			redirectHosts["www.#{cname}"] = cname

	
	targets.push target if target not in targets

	console.dir
		cnames: cnames
		redirectHosts: redirectHosts
		targets: targets

# read config on startup
if fs.existsSync PUBLIC_DIR
	owners = fs.readdirSync PUBLIC_DIR
	for owner in owners
		repos = fs.readdirSync "#{PUBLIC_DIR}/#{owner}"
		for repo in repos
			target = "#{owner}/#{repo}"
			readConfig target

app = connect()
app.use connect.logger 'dev'
app.use connect.bodyParser()
app.use serviceHookEndpoint
app.use vhostRewriter
app.use connect.static PUBLIC_DIR
app.listen PORT