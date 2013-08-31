{helpers} = require('faraday')
_ = require('underscore')
fs = require('fs')

APP_DIR = '../..'
HELPERS_DIR = '.'

filenameStart = './views/.compiled/'.length
filenameFinish = - 1 - '.html.underscorejs'.length

compile = ->
    helpers.forEachVisibleFileSync(HELPERS_DIR + '/views/.compiled', (filename, templateString) ->
        
        helpers.setRecursive(module.exports, 
                             filename[filenameStart..filenameFinish].split('/'), 
                             (data) -> _.template(templateString, (data ?= {}))))


if fs.existsSync(HELPERS_DIR + '/views/.compiled')
    precompile()