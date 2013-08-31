assert = require('assert')
fs = require('fs')
        
nonBlockForEachIter = (f, arr, callback, start) ->
    if arr.length is 0
        callback()
    else
        f((() -> nonBlockForEachIter(f, arr.slice(1), callback, start + 1)), arr[0], start)

exports.method = (obj, k) ->
    () -> 
        obj[k].apply(obj, arguments)

exports.addMethod = (obj, k, f) ->
    obj[k] = () -> f.apply(obj, arguments)

exports.nonBlockForEach = (f, arr, callback) -> 
    nonBlockForEachIter(f, arr, callback, 0)

   exports.nonBlockWhile = (cycle, callback) -> 
    next = (cont) ->
        if cont
            cycle.apply(next, [next])
        else
            callback()
    next(true)

exports.step = () -> applyify(Array.prototype.slice.call(arguments, 0))()
applyify = (arr) ->
    if arr.length is 0
        return ->
    else
        return () -> arr[0].apply(applyify(arr.slice(1)), arguments)

exports.forEachVisibleFile = (dir, callback) -> 
    fs.readdir(dir, ((err, subdirs) -> 
        assert.ifError(err)
        for subdir in subdirs
            unless subdir.match(/^\./)
                (() -> #This lambda protects fulldir with its own scope.
                    fulldir = dir + '/' + subdir
                    fs.stat(fulldir, ((err, stats) -> 
                        assert.ifError(err)
                        if stats.isDirectory()
                            #console.log("helpers.forEachVisibleFile: that #{fulldir} is a directory is #{stats.isDirectory()}.")
                            exports.forEachVisibleFile(fulldir, callback)
                        else if stats.isFile()
                            #console.log("helpers.forEachVisibleFile: #{fulldir} is a file.")
                            fs.readFile(fulldir, {encoding: 'utf8'}, ((err, contents) ->
                                assert.ifError(err)
                                callback(fulldir, contents)
                            ))
                        else
                            throw "helpers.forEachVisibleFile.coffee: I fail to recognize the type of data at #{fulldir}!"
                    ))
                )()
    ))

exports.forEachVisibleFileSync = (dir, callback) -> 
    subdirs = fs.readdirSync(dir)
    for subdir in subdirs
        unless subdir.match(/^\./)
            fulldir = dir + '/' + subdir
            stats = fs.statSync(fulldir) 
            if stats.isDirectory()
                #console.log("helpers.forEachVisibleFileSync: that #{fulldir} is a directory is #{stats.isDirectory()}.")
                exports.forEachVisibleFileSync(fulldir, callback)
            else if stats.isFile()
                #console.log("helpers.forEachVisibleFileSync: #{fulldir} is a file.")
                contents = fs.readFileSync(fulldir, {encoding: 'utf8'})
                callback(fulldir, contents)
            else
                throw "helpers.forEachVisibleFileSync.coffee: I fail to recognize the type of data at #{fulldir}!"

exports.setRecursive = (obj, keys, value) ->
    #console.log("helpers.setRecursive: I set the key [#{keys.join('][')}] equal to #{exports.truncate(value)}.")
    if keys.length is 1
        obj[keys[0]] = value
    else
        obj[keys[0]] ?= {}
        assert(typeof obj[keys[0]] is 'object', "helpers.setRecursive: I cannot set only the key of object, not a #{typeof obj[keys[0]]}!")
        exports.setRecursive(obj[keys[0]], keys[1..], value)

exports.getRecursive = (obj, keys) ->
    if keys.length is 0
        return obj
    else    
        assert(obj[keys[0]] isnt undefined or keys.length is 1, "getRecursive: obj[#{keys.join('][')}] isn't defined!")
        return exports.getRecursive(obj[keys[0]], keys[1..])

exports.truncate = (nOrStr, strOrNothing) ->
    if arguments[1]
        n = nOrStr
        str = String(strOrNothing)
    else 
        n = 30
        str = String(nOrStr)
    #console.log("I attempt to truncate the string #{str} to #{n} characters.")
    if n < 3
        #console.log("   I return the string '#{str[0...3]}'.")
        return str[0...3]
    if str.length <= n
        #console.log("   I return the string '#{str}'.")
        return str
    else
        #console.log("   I return the string '#{str[0...(n - 3)] + '...'}'.")
        return str[0...(n - 3)] + '...'

exports.prettyTime = () ->
    t = new Date()
    return "#{t.getMonth()+1}-#{t.getDate()} #{t.toLocaleTimeString()}"

exports.prettyFullTime = () ->
    t = new Date()
    return "#{t.getFullYear()}-#{t.getMonth()+1}-#{t.getDate()} #{t.toLocaleTimeString()}"


['log', 'info', 'error', 'warn', 'dir', 'time', 'timeEnd', 'trace'].forEach((cmd) ->
    exports[cmd + 'Stamped'] = (str) -> console[cmd](exports.prettyTime() + '> ' + str)
)

debugTasks = {}
exports.setDebugTask = (id, bool) -> debugTasks[id] = bool

exports.debugTask = (id, str) -> exports.infoStamped(id + ': ' + str) if debugTasks[id]

exports.load = (that) ->
    for key in Object.keys(exports)
        if key isnt 'load'
            #console.log("I load #{key}.")
            that[key] = exports[key]

exports.help = (f) -> f.apply(exports)

exports.params = (str) -> require('url').parse(str, true).query

exports.refreshMongourl = () ->
    if process.env.MONGOLAB_URI
        return process.env.MONGOLAB_URI
    if process.env.VCAP_SERVICES
        env = JSON.parse(process.env.VCAP_SERVICES)
        mongo = env['mongodb-1.8'][0]['credentials']
    else
        mongo = 
            hostname: "localhost"
            port: 27017
            username: ""
            password: ""
            name: ""
            db: "db"

    generate_mongo_url = (obj) ->
        obj.hostname = obj.hostname || 'localhost'
        obj.port = obj.port || 27017
        obj.db = obj.db || 'test'
        if obj.username and obj.password
            return "mongodb://" + obj.username + ":" + obj.password + "@" + obj.hostname + ":" + obj.port + "/" + obj.db
        else
            return "mongodb://" + obj.hostname + ":" + obj.port + "/" + obj.db

    return generate_mongo_url(mongo)

exports.mongourl = exports.refreshMongourl()

mongodb = require('mongodb')

exports.mongoColl = (collName, callback) ->
    mongodb.connect(exports.mongourl, ((err, conn) ->
        if err
            console.log('Error: helpers.mongoColl: I cannot establish a connection to the database!')
            throw err
        else
            conn.collection(collName, ((err, coll) ->
                if err
                    console.log("Error: helpers.mongoColl: I cannot connect to the collection #{collName}.")
                    throw err
                else
                    callback(conn, coll)
            ))
    ))

exports.thisPort = process.env.VCAP_APP_PORT || process.env.PORT || 3000