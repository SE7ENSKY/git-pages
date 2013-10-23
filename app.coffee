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
TMP_DIR = "#{__dirname}/tmp"
ROOT_HOST = process.env.ROOT_HOST or "localhost"
rootHostRegexed = ROOT_HOST.replace ///\.///g, '\\.'

cnames = {}
redirectHosts = {}
targets = []

serviceHookEndpoint = (req, res, next) ->
	console.dir req.body
	if req.method is 'POST' and req.body
		try
			# ToDo: validate input

			payload = if req.body.payload
				JSON.parse req.body.payload
			else
				req.body
			res.end()
			handleRepository payload.repository.url
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

handleRepository = (url) ->
	m = url.match ///([a-zA-Z0-9\-\.]+)/([a-zA-Z0-9\-\.]+)\.git$///
	if not m
		m = url.match ///([a-zA-Z0-9\-\.]+)/([a-zA-Z0-9\-\.]+)$///
	owner = m[1]
	repo = m[2]
	owner = owner.toLowerCase()
	repo = repo.toLowerCase()
	rnd = Math.round(Math.random() * 1000000)
	exec """
		mkdir -p #{TMP_DIR}/#{rnd}
		git clone --depth=1 --single-branch --branch=gh-pages #{url} #{TMP_DIR}/#{rnd}
		[ -d "#{PUBLIC_DIR}/#{owner}/#{repo}" ] && rm -rf #{PUBLIC_DIR}/#{owner}/#{repo}
		mkdir -p #{PUBLIC_DIR}/#{owner}
		mv #{TMP_DIR}/#{rnd} #{PUBLIC_DIR}/#{owner}/#{repo}
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