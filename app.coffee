connect = require 'connect'

app = connect()
app.use connect.logger 'dev'
app.use connect.static 'public'
app.use connect.json()
app.use (req, res) ->
	console.dir req.body
	res.end 'ok'
app.listen process.env.PORT or 3000