{helpers} = require('faraday')
fs = require('fs')
mongodb = require('mongodb')
ObjectID = mongodb.ObjectID
assert = require('assert')
step = require('step')
model = module.exports
_ = require('underscore')

helpers.setDebugTask('models', off)

Set = (() -> 
    #A helper class to hold connections to the database
    ConnCollection = (value) ->
        helpers.debugTask('models', "ConnCollection: I attempt to create a ConnCollection.")
        result = Object.create(prototypeOfConnCollection)
        result.value = value
        helpers.debugTask('models', "ConnCollection: I create a ConnCollection: #{helpers.truncate(50, result)}.")
        return result

    prototypeOfConnCollection = {}

    prototypeOfConnCollection.toString = () -> "[ConnCollection value: [#{this.value.map(String)}]]"

    ['push', 'pop', 'map', 'forEach', 'every', 'some'].forEach((k) -> #this MUST be forEach, NOT for..in; for..in does not properly scope; when k changes, I call the wrong method.
        prototypeOfConnCollection[k] = () -> 
            Array.prototype[k].apply(this.value, arguments)
    )

    prototypeOfConnCollection.concat = (other) -> ConnCollection(@value.concat(other.value))

    prototypeOfConnCollection.close = () -> 
        helpers.debugTask('models', "I close the connections: #{helpers.truncate(30, this)}.")
        @forEach((conn) -> conn.close())


    prototypeOfMongoDBCursorWrapper = {}

    prototypeOfMongoDBCursorWrapper.next = (callback) ->
        @value.nextObject((err, e) =>
            assert.ifError(err)
            if e is null
                helpers.debugTask('models', "prototypeOfMongoDBCursorWrapper: I find no more documents!")
                callback(undefined)
            else
                result = @set.create(e)
                helpers.debugTask('models', "prototypeOfMongoDBCursorWrapper: I return the document (excluding functions) #{JSON.stringify(result)}.")
                callback(result)
        )

    MongoDBCursorWrapper = (set, cursor) ->
        helpers.debugTask('models', "MongoDBCursorWrapper: I have been called with #{helpers.truncate(String(Array.prototype.map.call(arguments, String)))}.")
        result = Object.create(prototypeOfMongoDBCursorWrapper)
        result.value = cursor
        result.set = set
        return result




    constructor = (nameParts) -> 
        helpers.debugTask('models', "constructor: I have been called with #{helpers.truncate(String(Array.prototype.map.call(arguments, String)))}.")
        result = Object.create(prototypeOfSet) 
        result.nameParts = nameParts
        return result

    prototypeOfSet = {}

    prototypeOfSet.toString = () -> "[Set #{@dbName()}]"

    prototypeOfSet.dbName = () -> @last.dbName()            #The first set overrides this method.

    prototypeOfSet.create = (attrs) -> @last.create(attrs)  #The first set overrides this method.

    prototypeOfSet.cursor = (f) ->  
        that = this
        helpers.debugTask('models', "prototypeOfSet.cursor: I try to create the cursor for '#{@dbName()}'.")
        helpers.mongoColl(@dbName(), ((conn, coll) -> 
            helpers.debugTask('models', "prototypeOfSet.cursor: I create the cursor with coll #{helpers.truncate(30, coll)}.")
            f(ConnCollection([conn]), MongoDBCursorWrapper(that, coll.find({})))))



    prototypeOfCursor = {}

    prototypeOfCursor.toString = () -> "[Cursor #{@set.dbName()}]"




    prototypeOfSet.where = (f) ->
        helpers.debugTask('models', "prototypeOfSet.where: I have been called with #{helpers.truncate(String(Array.prototype.map.call(arguments, String)))}.")
        result = Object.create(prototypeOfWhereSet)
        result.last = this
        result.f = f 
        return result

    prototypeOfWhereSet = Object.create(prototypeOfSet)

    prototypeOfWhereSet.cursor = (callback) ->
        helpers.debugTask('models', "prototypeOfWhereSet.cursor: I have been called with #{helpers.truncate(String(Array.prototype.map.call(arguments, String)))}.")
        that = this
        @last.cursor((conns, cursor) ->
            callback(conns, WhereCursor(that, cursor))
        )

    WhereCursor = (set, lastCursor) ->
        helpers.debugTask('models', "WhereCursor: I have been called with #{helpers.truncate(String(Array.prototype.map.call(arguments, String)))}.")
        result = Object.create(prototypeOfWhereCursor)
        result.last = lastCursor
        result.set = set
        return result

    prototypeOfWhereCursor = Object.create(prototypeOfCursor)

    prototypeOfWhereCursor.next = (callback) ->
        helpers.debugTask('models', "prototypeOfWhereCursor.next: I have been called with #{helpers.truncate(String(Array.prototype.map.call(arguments, String)))}.")
        that = this
        @last.next((e) ->
            if e is undefined
                callback(undefined)
            else if that.set.f(e)
                callback(e)
            else
                that.next(callback)
        )



    prototypeOfSet.map = (f) ->
        helpers.debugTask('models', "prototypeOfSet.map: I have been called with #{helpers.truncate(String(Array.prototype.map.call(arguments, String)))}.")
        result = Object.create(prototypeOfMapSet)
        result.f = f
        result.last = this
        return result

    prototypeOfMapSet = Object.create(prototypeOfSet)

    prototypeOfMapSet.cursor = (callback) ->
        that = this
        @last.cursor((conns, cursor) ->
            callback(conns, MapCursor(that, cursor))
        )

    MapCursor = (set, lastCursor) ->
        result = Object.create(prototypeOfMapCursor)
        result.set = set
        result.last = lastCursor
        return result

    prototypeOfMapCursor = Object.create(prototypeOfCursor)

    prototypeOfMapCursor.next = (callback) ->
        that = this
        @last.next((e) ->
            if e is undefined
                callback(undefined)
            else
                callback(that.set.f(e))
        )



    prototypeOfSet.each = (f) ->
        helpers.debugTask('models', "prototypeOfSet.each: I have been called with #{helpers.truncate(String(Array.prototype.map.call(arguments, String)))}.")
        result = Object.create(prototypeOfEachSet)
        result.f = f
        result.last = this
        return result

    prototypeOfEachSet = Object.create(prototypeOfSet)

    prototypeOfEachSet.cursor = (callback) ->
        that = this
        @last.cursor((conns, cursor) ->
            callback(conns, EachCursor(that, cursor))
        )

    EachCursor = (set, lastCursor) ->
        result = Object.create(prototypeOfEachCursor)
        result.set = set
        result.last = lastCursor
        return result

    prototypeOfEachCursor = Object.create(prototypeOfCursor)

    prototypeOfEachCursor.next = (callback) ->
        @last.next((e) =>
            if e is undefined
                callback(undefined)
            else
                @set.f((() -> callback(e)), e)
        )



    helpers.setDebugTask('groupByKeyReduce', off)
    prototypeOfSet.groupByKeyReduce = (elem2Key, elem2Initial, iterator) ->
        result = Object.create(prototypeOfGroupByKeyReduceSet)
        result.last = this
        result.elem2Key = elem2Key
        result.elem2Initial = elem2Initial
        result.iterator = iterator
        return result

    prototypeOfGroupByKeyReduceSet = Object.create(prototypeOfSet)

    prototypeOfGroupByKeyReduceSet.cursor = (callback) ->
        @last.cursor((conns, cursor) =>
            callback(conns, GroupByKeyReduceCursor(this, cursor))
        )

    GroupByKeyReduceCursor = (set, lastCursor) ->
        result = Object.create(prototypeOfGroupByKeyReduceCursor)
        result.set = set
        result.last = lastCursor
        result.hasLoaded = false
        result.loaded = []
        return result

    prototypeOfGroupByKeyReduceCursor = Object.create(prototypeOfCursor)

    prototypeOfGroupByKeyReduceCursor.loadAll = (callback) ->
        helpers.debugTask('models', "prototypeOfGroupByKeyReduceCursor.loadAll: I am called.")
        thiscursor = this
        grouped = []            

        placeElem = (e) ->
            key = thiscursor.set.elem2Key(e)
            for [k, vs] in grouped
                if key is k
                    vs.push(e)
                    return
            grouped.push([key, [e]])

        helpers.step((() ->
                        nextStep = this

                        eachElem = () ->
                            thiscursor.last.next((e) ->
                                if e is undefined
                                    nextStep()
                                else
                                    placeElem(e)
                                    eachElem()
                            )
                        eachElem()
                     ),(() ->
                        for [k, vs] in grouped
                            initial = thiscursor.set.elem2Initial(vs.pop())
                            reduced = vs.reduce(thiscursor.set.iterator, initial)
                            helpers.debugTask('groupByKeyReduce', "The time totals to #{reduced.value}.")
                            thiscursor.loaded.push(reduced)
                        thiscursor.hasLoaded = true
                        callback()
                     ))

    prototypeOfGroupByKeyReduceCursor.next = (callback) ->
        if @loaded.length > 0
            result = @loaded.pop()
            callback(result)
        else if @hasLoaded 
            callback(undefined)
        else
            @loadAll(() =>
                @next(callback)
            )



    prototypeOfSet.cross = (other) ->
        result = Object.create(prototypeOfCrossSet)
        result.last = this
        result.other = other
        return result

    prototypeOfCrossSet = Object.create(prototypeOfSet)

    prototypeOfCrossSet.cursor = (callback) -> 
        return @last.cursor((lastConns, l) => 
                    @other.cursor((otherConns, o) => 
                        callback(lastConns.concat(otherConns), 
                                 CrossCursor(this, l, o))))

    CrossCursor = (set, lastCursor, otherCursor) -> 
        result = Object.create(prototypeOfCrossCursor)
        result.set = set
        result.last = lastCursor
        result.other = otherCursor
        result.takeFrom = lastCursor
        result.takeNextFrom = otherCursor
        result.fromLast = []
        result.fromOther = []
        result.loaded = []
        return result

    prototypeOfCrossCursor = Object.create(prototypeOfCursor)

    prototypeOfCrossCursor.firstElem = (callback) ->
        @last.next((l) => 
            @other.next((o) =>
                if l is undefined or o is undefined
                    callback(undefined)
                else
                    @fromLast.push(l)
                    @fromOther.push(o)
                    callback([l, o])
            )
        )

    prototypeOfCrossCursor.onTakeFromNext = (e1, callback) -> 
        if @takeFrom is @last
            @fromLast.push(e1)
            for e2 in @fromOther
                @loaded.push([e1, e2])
            [@takeFrom, @takeNextFrom] = [@takeNextFrom, @takeFrom]
            callback(@loaded.pop())
        else if @takeFrom is @other
            @fromOther.push(e1)
            for e2 in @fromLast
                @loaded.push([e2, e1])
            [@takeFrom, @takeNextFrom] = [@takeNextFrom, @takeFrom]
            callback(@loaded.pop())
        else
            throw "prototypeOfCrossCursor.next: @takeFrom is neither @last nor @other, but #{@takeFrom}!"

    prototypeOfCrossCursor.next = (callback) ->
        unless @fromLast.length > 0 or @fromOther.length > 0
            @firstElem(callback)
        else if @loaded.length > 0 
            result = @loaded.pop()
            callback(result)
        else 
            @takeFrom.next((e) =>
                unless e is undefined
                    @onTakeFromNext(e, callback)
                else
                    @takeFrom = @takeNextFrom #Now @takeFrom and @takeNextFrom are the same; both will never equal that @takeFrom just was. 
                    @takeNextFrom.next((e) =>
                        unless e is undefined
                            @onTakeFromNext(e, callback)
                        else
                            callback(undefined)
                    )
            )


    prototypeOfSet.joinUsing = (keys, other) ->
        return this.cross(other).where(([l, o]) ->
            result = l._id.equals(o._id) and keys.every((key) -> l[key] is o[key])
            return result
        ).map(([l, o]) ->
            _.extend(o, l)
        )

    prototypeOfSet.join = (other) ->
        return @joinUsing([], other)



    prototypeOfSet.createAll = (list) -> CreateAllSet(this, list)

    CreateAllSet = (last, arr) ->
        result = Object.create(prototypeOfCreateAllSet)
        result.last = last
        result.newModels = arr.map(helpers.method(last, 'create'))
        return result

    prototypeOfCreateAllSet = Object.create(prototypeOfSet)

    prototypeOfCreateAllSet.cursor = (callback) ->
        that = this
        @last.cursor((conns, cursor) ->
            callback(conns, CreateAllCursor(that, cursor))
        )

    CreateAllCursor = (set, lastCursor) ->
        result = Object.create(prototypeOfCreateAllCursor)
        result.set = set
        result.last = lastCursor
        result.loaded = set.newModels
        return result

    prototypeOfCreateAllCursor = Object.create(prototypeOfCursor)

    prototypeOfCreateAllCursor.next = (callback) ->
        if @loaded.length > 0
            callback(@loaded.pop())
        else 
            @last.next(callback)


    prototypeOfSet.invoke = (str, rest...) ->
        helpers.debugTask('models', "prototypeOfSet.invoke: I have been called with #{helpers.truncate(String(Array.prototype.map.call(arguments, String)))}.")
        if rest.length is 1
            args = []
            callback = rest[0]
        else
            args = rest[0]
            callback = rest[1]
        immediateEach.apply(this, 
                            [((callback, item) -> 
                                item[str].apply(item, Array.prototype.concat.call(args, callback))
                             ), 
                             callback])
    immediateEach = (f, callback) -> #Streamline by calling each element in paralell.
        @cursor((conns, cursor) => 
            eachElem = (e) =>
                conns.close()
                if e is undefined
                    callback()
                else
                    f((() -> cursor.next(eachElem)), e)
            cursor.next(eachElem)
        )


    prototypeOfSet.every = (cond, callback) ->
        this.cursor((conns, cursor) -> 
            iter = () ->
                cursor.next((e) =>
                    if e is undefined
                        conns.close()
                        callback(true)
                    else if not cond(e)
                        conns.close()
                        callback(false)
                    else
                        iter(conns, cursor, cond, callback)
                )
            iter()
        )

    prototypeOfSet.some = (cond, callback) ->
        this.cursor((conns, cursor) -> 
            iter = () ->
                cursor.next((e) =>
                    if e is undefined
                        conns.close()
                        callback(false)
                    else if cond(e)
                        conns.close()
                        callback(true)
                    else
                        iter(conns, cursor, cond, callback)
                )
            iter()
        )

    ###
        prototypeOfSet.reduce = (initial, f, callback) ->
            this.cursor((conns, cursor) -> 
                current = initial
                while cursor.hasNext()
                    current = f(current, cursor.next())
                conns.close()
                callback(current)
            )

        updateCursor = (coll, cursor, modifier, callback) ->
            unless cursor.hasNext()
                callback()
            else
                n = cursor.next()
                oldID = n._id
                coll.update({_id: oldID}, (() -> 
                    updateCursor(coll, cursor, modifier, callback)
                ))
        prototypeOfSet.update = (modifier, callback) ->
            that = this
            step((() -> 
                        helpers.mongoColl(that.dbName(), this)
                ),((conn, coll) ->
                        that.last.cursor((conns, cursor) -> 
                            updateCursor(coll.find(), cursor, modifier, (() -> this(conns.concat([conn]))))
                        )
                ),((conns) ->
                        conns.close()
                        callback()
                ))
    ###
    prototypeOfSet.save = (callback) ->
        helpers.debugTask('models', "prototypeOfSet.save: I have been called with #{helpers.truncate(String(Array.prototype.map.call(arguments, String)))}.")        
        this.invoke('save', callback)

    prototypeOfSet.destroy = (callback) -> 
        helpers.debugTask('models', "prototypeOfSet.destroy: I have been called with #{helpers.truncate(String(Array.prototype.map.call(arguments, String)))}.")
        this.invoke('destroy', callback)

    prototypeOfSet.count = (callback) ->
        @cursor((conns, cursor) ->
            onNext = (e, callback) ->
                if e is undefined
                    conns.close()
                    callback(0)
                else
                    cursor.next((e) -> onNext(e, (n) -> callback(1 + n)))
            cursor.next((e) ->
                onNext(e, callback)
            )
        )

    prototypeOfSet.toArray = (callback) ->
        result = []
        @cursor((conns, cursor) ->
            cursor.next((e) ->
                if e is undefined
                    conns.close()
                    callback(result)
                else
                    result.push(e)
                    cursor.next(arguments.callee)
            )
        )

    prototypeOfSet.one = (callback) ->
        @cursor((conns, cursor) ->
            cursor.next((e) ->
                conns.close()
                callback(e)
            )
        )

    prototypeOfSet.then = (callback) ->
        @cursor((conns, cursor) ->
            cursor.next((result) ->
                if result is undefined
                    conns.close()
                    callback()
                else
                    cursor.next(arguments.callee)
            )
        )


    return constructor

)()

prototypeOfModel = {}

prototypeOfModel.save = (callback) ->
    @_id ?= ObjectID()
    helpers.mongoColl(@dbName, ((conn, coll) =>
        coll.save(this, {safe: true}, (() =>
            conn.close()
            callback()
        ))
    ))

prototypeOfModel.destroy = (callback) ->
    if not @_id
        callback() 
    helpers.mongoColl(@dbName, ((conn, coll) =>
        coll.remove({_id: @_id}, {w: 2}, ((err, n) ->
            assert.ifError(err)
            assert(n is 1)
            conn.close()
            callback()
        ))
    ))
        



Model = (dbName) ->
    result = Object.create(prototypeOfModel)
    result.dbName = dbName
    return result



namePart = (dir) -> 
    m = dir.match(/\w+(?=\.\w+$)/)
    assert(m)
    return m[0]

nameParts = (dir) ->
    result = dir.split('/')
    result[result.length - 1] = namePart(result[result.length - 1])
    return result

helpers.forEachVisibleFileSync('./models', ((partdir) -> 
    modelDir = '../.' + partdir #this is only the dir relative to the main module. We need to get there with '../.'.
    modelNameParts = nameParts(partdir[2..])[1..]
    dbName = modelNameParts.join('.')

    set = Set(modelNameParts) 
    set.dbName = () -> dbName

    prototypeOfNewModel = Model(dbName)
    newSet = require(modelDir)(prototypeOfNewModel, set)

    oldSet = Set(modelNameParts) 
    oldSet.dbName = () -> dbName

    for k, v in oldSet
        unless newSet[k] is v
            helpers.warnStamped("You have altered [#{modelNameParts.join('.')} Set]##{k}.")

    if newSet.create is oldSet.create
        newSet.create = (obj) -> 
            result = Object.create(prototypeOfNewModel)
            for k, v of obj
                result[k] = v
            return result

    helpers.setRecursive(module.exports, modelNameParts, newSet)

    assert(helpers.getRecursive(module.exports, modelNameParts) is newSet)))

###
WARNING: Some methods have callbacks. When they invoke the callback, they do not gurantee that the db connection is closed.

where((entry) -> Bool) 
groupBy((a, b) -> Bool)                             --unimplemented
groupByKey((entry) -> key)                          --unimplemented
groupByKeyReduce((entry) -> key, (key) -> initial, (last, entry) -> next) 
plus/concat(another_iterator)                       --unimplemented
minus/without(another_iterator)                     --unimplemented
cross(another_iterator)                             
join(another_iterator)                              --unimplemented
joinUsing([key1, key2..])
intersect(another_iterator)                         --unimplemented
map((item) -> newItem)                              
pluck(propName)                                     --unimplemented
union(another_iterator)                             --unimplemented
intersectAll(another_iterator)                      --unimplemented
limit(Number)                                       --unimplemented
find(attrs)                                         --unimplemented
contains(elem)                                      --unimplemented
uniq()                                              --unimplemented
insert(item)                                        --unimplemented
insertAll(items)                                    --unimplemented

                                                        
                                                    
one() #selects a random model                       
some((entry) -> Bool, callback)                     
every((entry) -> Bool, callback)                        
reduce(initial, (acc, entry) -> newAcc, callback)   
invoke(func or funcName)                            
each((next, item) -> ... item.save?, callback)            
destroy(callback)
removeMongo(object_selector, callback)              --unimplemented
update((item) -> newItem, callback)
save(callback)
toArray(callback)
count(callback)
then(callback)                                              

model.toSet

obj = model.Task.create(args)
model.Task.where((item) -> item._id is 148912)
model.Task.where((a) -> model.Task.every((b) -> b._id < a._id)).destroy(callback)

myTask = model.Task.create('Run')
myTask.save(() ->
    #moreStuff...
))
myTask.refresh((newTask) ->
    newTask.f = (x) -> x
    newTask.save(() ->
        #moreStuff...
    ))
))


###


###
prototypeOfSet.insert = (item, callback) ->
    that = this
    step((() ->
                helpers.mongoColl(that.name(), this)
         ), ((conn, coll) ->
                coll.insert(item, {safe: true}, this)
         ), ((err, inserted) -> 
                assert.ifError(err)
                conn.close()
                callback(inserted)))
###


###
stripExtension = (str) -> 
    m = str.match(/^\w+/)
    unless m
        throw "stripExtension: I cannot strip the extension from '#{str}'."
    return m[0]
###

###
    prototypeOfSet.name = () -> 
        assert(@name or @last, "prototypeOfSet.name: #{this} has neither a name nor a last Set.")
        return @name or @last.name()
###



###
    prototypeOfCursor.next = () ->
        helpers.debugTask('models', "prototypeOfCursor.next: I attempt to return the next item.")
        if @hasNext()
            i = @loaded.pop()
            helpers.debugTask('models', "prototypeOfCursor.next: I return the item #{helpers.truncate(i)}.")
            return i
        else 
            throw StopIteration
###

###
    prototypeOfCreateAllCursor.hasNext = () ->
        if @loaded.length > 0
            return true
        else if @last.hasNext()
            @loaded.push(@last.next())
            return true
        else
            return false
###

###
    #I define set.create twice to resolve circular dependencies when the model calls all models.
    set.create = () -> require(modelDir)(Model(set.dbName())).apply({}, arguments)
    
    modelSet = require(modelDir)(Model(set.dbName()))

    set.create = () -> modelConstructor.apply({}, arguments)
###

###
        else unless @last.hasNext() or @other.hasNext()
            return false
        else 
            if not @last.hasNext() 
                @takeFrom = @other
            else if not @other.hasNext()
                @takeFrom = @last
            if @takeFrom is @last
                n = @last.next()
                @fromOther.forEach((item) ->
                    @loaded.push([n, item])
                )
                @takeFrom = @other
            else if @takeFrom is @other
                n = @other.next()
                @fromLast.forEach((item) ->
                    @loaded.push([item, n])
                )
                @takeFrom = @last
            return true
###

###
    prototypeOfSet.groupByReduce = (last, areSimilar, entry2Initial, reduce) ->
        result = Object.create(prototypeOfGroupByReduceSet)
        result.last = last
        result.areSimilar = areSimilar
        result.entry2Initial = entry2Initial
        result.reduce = reduce
        return result

    prototypeOfGroupByReduceSet = Object.create(prototypeOfSet)

    prototypeOfGroupByReduceSet.cursor = (callback) ->
        return callback(@last.conns, GroupByReduceCursor(this, @last.cursor))

    GroupByReduceCursor = (set, lastCursor) ->
        result = Object.create(prototypeOfGroupByReduceCursor)
        result.set = set
        result.last = lastCursor

    prototypeOfGroupByReduceCursor = Object.create(prototypeOfCursor)


    prototypeOfGroupByReduceCursor.hasNext = (() ->
        result = () ->
            if @loaded
                return @loaded.length > 0
            else
                @loaded = placeInGroups(@set.areSimilar, lastCursor).map((group) ->
                    initial = @set.entry2Initial(group[0])
                    return group.reduce(initial, @set.reduce)
                )

        placeInGroups = (areSimilar, cursor) ->
            result = []
            while cursor.hasNext()
                result = placeInGroup(cursor.next(), result, areSimilar)
            return result

        placeInGroup = (item, arr, areSimilar) ->
            if arr.length is 0
                return [[item]]
            else if areSimilar(item, arr[0][0])
                return [arr[0].concat([item])].concat(arr.slice(1))
            else
                return [arr[0]].concat(placeInGroup(item, arr.slice(1), areSimilar))

        return result
    )()
###