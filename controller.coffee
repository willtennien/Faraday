{helpers} = require('faraday')
assert = require('assert')

APP_DIR = '../..'

filenameForRequire = (filename) -> APP_DIR + '/' + filename    # '../.' takes us to the root dir relative to 'node_modules/controller'

controllerNameParts = (filename) ->
    m = filename.match(/controllers\/(.+?).coffee$/)
    assert(m, "I cannot parse the filename '#{filename}'!")
    return m[1].split('/')

helpers.forEachVisibleFileSync('controllers', ((filename, data) ->

    controller = require(filenameForRequire(filename))

    helpers.setRecursive(module.exports, 
                         controllerNameParts(filename), 
                         controller) 

))
