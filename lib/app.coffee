{helpers, model, route} = require('faraday')
http = require('http')

http.Server((req, res) -> 
    route(req)(req, res)
).listen(helpers.thisPort)

helpers.logStamped("I am born on port #{helpers.thisPort}.")
