url = require('url')
fs = require('fs')
{controller, config, helpers} = require('faraday')
_ = require('customscore')

APP_DIR = '../..' #I assume that we are in APP_DIR/node_modules/faraday.

routeObject = _.clone(controller)

routeObject.assets = (req, res) ->
    pathname = '.' + transformPath(url.parse(req.url).pathname)
    console.log(pathname)
    debugger
    fs.readFile(pathname, ((err, data) ->
        if err
            res.writeHead(404)
            res.end(err.toString())
        else
            if _.protract(config, 'assets', 'Cache-Control')?
                headers =  
                    'Cache-Control': config.assets['Cache-Control']
            else 
                headers = {}
            res.writeHead(200, headers)
            res.end(data)
    ))

ifFunctionElseUndefined = (x) -> if typeof x is 'function' then x else undefined

pageNotFound = (_, res) -> 
    res.writeHead(404, {'Content-Type': 'text/plain'})
    res.end('I cannot find the page you seek!\n')

transformPath = (pathname) ->
    if config.routes?
        config.routes[pathname] ? pathname
    else
        pathname

module.exports = (req) ->
    pathname = url.parse(req.url).pathname
    pathParts = transformPath(pathname).match(/\/[^?]*/)[0].split('/')[1..]
    console.log()
    helpers.logStamped("I receive a request for #{req.url} and parse it to [#{pathParts.join('][')}].")
    switch pathParts[0]
        when 'assets' 
            return routeObject.assets
        else
            return ifFunctionElseUndefined(_.protract.apply({}, [routeObject].concat(pathParts))) or pageNotFound
