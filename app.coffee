connect = require 'connect'

app = connect()
app.use connect.logger 'dev'
app.use connect.static 'public'
app.listen process.env.PORT or 3000