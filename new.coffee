{exec} = require('child_process')
fs = require('fs')

#module.exports = ->
dirs = [
    'assets'
    'assets/coffeescripts'
    'assets/javascripts'
    'assets/styles'
    'models'
    'modooses'
    'views'
    'controllers'
]

for dir in dirs
    console.log("I make the directory '#{dir}'.")
    exec("mkdir #{dir}")

files = [
    'develop'
    'app.coffee'
    'server.js'
    'Procfile'
    'config.coffee'
]

for filename in files
    switch filename
        when 'Procfile'
            console.log("I build Profile (for Heroku)")
        when 'server.js'
            console.log("I build server.js (for AppFog)")
        else
            console.log("I build #{filename}.")

    fs.writeFileSync(process.cwd() + '/' + filename
                     fs.readFileSync('node_modules/faraday/lib/' + filename))
