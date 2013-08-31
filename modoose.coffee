{helpers} = require('faraday')
assert = require('assert')
mongoose = require('mongoose')

handlers = do ->
    cbs = []
    invoked = false

    self = 
        push: (cb) ->
            cbs.push(cb)
            if invoked
                self.invoke()
        invoke: () ->
            invoked = true
            while 0 < cbs.length
                cbs.shift()()

APP_DIR = '../..'

filenameForRequire = (filename) -> APP_DIR + '/' + filename    # '../.' takes us to the root dir relative to 'node_modules/controller'

modooseNameParts = (filename) ->
    m = filename.match(/modooses\/(.+?).coffee$/)
    assert(m, "I cannot parse the filename '#{filename}'!")
    return m[1].split('/')

modooses = {}

helpers.forEachVisibleFileSync('modooses', ((filename, data) ->

    modoose = require(filenameForRequire(filename))

    helpers.setRecursive(modooses, 
                         modooseNameParts(filename), 
                         modoose)

    mongoose.connection.open(helpers.mongourl
                             -> handlers.invoke())))

module.exports = (cb) -> handlers.push(-> cb(modooses))

