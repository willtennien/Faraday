fs = require('fs')

try
    module.exports = require(process.cwd() + '/config.coffee')
catch e
    console.log(e)
    # so module.exports is {}