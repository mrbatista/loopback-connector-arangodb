# node modules

# Module dependencies
url = require 'url'
merge = require 'extend'
async = require 'async'
_ = require 'underscore'
Connector = require('loopback-connector').Connector
GeoPoint = require('loopback-datasource-juggler').GeoPoint
debug = require('debug') 'loopback:connector:arango'

# arango
ajs = require 'arangojs'
qb = require 'aqb'


exports.generateConnObject = generateConnObject = (settings) ->
  if settings.url
    parsed = url.parse settings.url

    generated = {}
    generated.protocol = 'http:'
    generated.hostname = (parsed.hostname or '127.0.0.1')
    generated.port     = (parsed.port or 8529)

    generated.auth = parsed.auth if parsed.auth?

    database = parsed.path[1..].split('/')[0] or 'loopback_db'

    dbUrl = url.format generated
  else
    obj = {}
    obj.protocol = 'http:'
    obj.hostname = (settings.host or '127.0.0.1')
    obj.port = (settings.port or 8529)

    obj.auth = "#{settings.username}:#{settings.password}" if settings.username and settings.password

    database = (settings.database or settings.db or 'loopback_db')

    dbUrl = url.format obj

  promise = (settings.promise or false)

  # TODO: add more arango specifig objects for a connection

  return {
    url: dbUrl
    databaseName: database
    promise: promise
  }


###
Decide if id should be included
@param {Object} fields
@returns {Boolean}
@private
###
_idIncluded = (fields, idName) ->
  if !fields then return true

  if Array.isArray fields
    return fields.indexOf idName  >= 0

  if fields[idName]
    # Included
    return true

  if idName in fields and !fields[idName]
    # Excluded
    return false

  for f in fields
    return !fields[f]; # If the fields has exclusion

  return true


###
  Initialize the ArangoDB connector for the given data source

  @param dataSource [DataSource] The data source instance
  @param callback [Function] The callback function
###
initialize = (dataSource, callback) ->
  return if not ajs?
  dataSource.driver = ajs;

  settings = generateConnObject dataSource.settings

  dataSource.connector = new ArangoDBConnector settings, dataSource
  dataSource.connector.connect callback if callback?

exports.initialize = initialize


###
  Loopback Arango Connector

  @author Navid Nikpour
###
class ArangoDBConnector extends Connector
  # @extend: (obj) ->
  #   for key, value of obj when key not in ['extended', 'included']
  #     @[key] = value
  #
  #   obj.extended?.apply(@)
  #   this
  #
  # @include: (obj) ->
  #   for key, value of obj when key not in ['extended', 'included']
  #     # Assign properties to the prototype
  #     @::[key] = value
  #
  #   obj.included?.apply(@)
  #   this
  #


  ###
    The constructor for ArangoDB connector
    @constructor

    @param dataSource [Object] Object to connect this connector to a data source
    @option settings host [String] The host/ip address to connect with
    @option settings port [Number] The port to connect with
    @option settings database/db [String] The database to connect with
    @option settings headers [Object] Object with header to include in every request

    @param dataSource [DataSource] The data source instance
  ###
  constructor: (settings, dataSource) ->
    super 'arangodb', settings
    # debug
    @debug = dataSource.settings.debug or debug.enabled

    # link to datasource
    @dataSource = dataSource

    # Query builder
    @qb = require('aqb')

    @db = ajs @settings

    @api = @db.route '_api'

    @returnVariable = 'result'


  # one file per functionality
  # @extend require('./CoreMixin')
  # =============
  # = CoreMixin =
  # =============
  ###
    Connect to ArangoDB

    @param callback [Function] The callback function, called the with created connection
  ###
  connect: (callback) ->

    debug 'ArangoDB connection is called with settings: #{JSON.stringify @settings}' if @debug

    process.nextTick () ->
      callback && callback null, @db

  ###
    Get the types of this connector

    @return [Array<String>] The types of connectors this connector belongs to
  ###
  getTypes: () ->
    return ['db', 'nosql', 'arangodb']


  ###
    The default Id type

    @return [Object] The class to build the Id Value with

  ###
  getDefaultIdType: () ->
    return String

  ###
    Get the model class for a certain model name

    @param model [String] The model name to lookup

    @return [Object] The model class of this model
  ###
  getModelClass: (model) ->
    return @_models[model]


  ###
    Get the collection name for a certain model name

    @param model [String] The model name to lookup

    @return [Object] The collection name for this model
  ###
  getCollectionName: (model) ->
    modelClass = @getModelClass(model)

    if modelClass.settings.arangodb
      model = modelClass.settings.arangodb?.collection or model

    return model


  ###
    Converts the retrieved data from the database to JSON, based on the properties of a given model

    @param model [String] The model name to look up the properties
    @param data [Object] The data from DB

    @return [Object] The converted data as an JSON Object
  ###
  fromDatabase: (model, data) ->
    return null if not data?

    props = @getModelClass(model).properties

    for key, val of props
      #Buffer type
      if data[key]? and val? and val.type is Buffer
        data[key] = new Buffer(data[key])

      # Date
      if data[key]? and val? and val.type is Date
        data[key] = new Date data[key]

      # GeoPoint
      if data[key]? and val? and val.type is GeoPoint
        data[key] = new GeoPoint { lat: data[key].lat, lng: data[key].lng }

    return data


  ###
    Execute a query with AQL and binded variables

    @param query [String|Object] The AQL query to execute
    @param bindVars [Object] The variables bound to the AQL query
    @param callback [Function] The callback function, called with a (possible) error object and the query's cursor
  ###
  execute: (query, bindVars, callback) ->

    self = this

    if typeof bindVars is 'function' and !callback?
      callback = bindVars
      bindVars = {}

    context =
      req:
        aql: query
        params: bindVars

    @notifyObserversAround 'execute', context, (context, done) ->
      self.executeAQL context.req.aql, context.req.params, (err, result) ->
        context.res = result and result._result
        done err, result
    , callback


  executeAQL: (query, bindVars, callback) ->
    if @debug
      if typeof query.toAQL is 'function'
        q = query.toAQL()
      else
        q = query

      debug "query: #{q} bindVars: #{JSON.stringify bindVars}"

    @db.query query, bindVars, (err, cursor) ->
      # workaround: when there is no error (e.g. wrong AQL syntax etc.) and no cursor, the authentication failed
      if not err? and cursor.length = 0
        authErr = Error 'Authentication failed'
        callback authErr
      else
        callback err, cursor


  ###
    Checks the version of the ArangoDB

    @param callback [Function] The calback function, called with a (possible) error object and the server versio
  ###
  getVersion: (callback) ->
    if @version?
      callback null, @version
    else
      @api.get 'version', (err, result) ->
        callback err if err
        @version = result.body
        callback null, @version


  # @extend require('./CrudMixin')
  # ==============
  # = CRUD Mixin =
  # ==============
  ###
    Create a new model instance for the given data

    @param model [String] The model name
    @param data [Object] The data to create
    @param callback [Function] The callback function, called with a (possible) error object and the created object's id
  ###
  create: (model, data, callback) ->
    debug "create model #{model} with data: #{JSON.stringify data}" if @debug

    self = this

    idValue = @getIdValue(model, data)
    idName = @idName(model)

    if !idValue? or typeof idValue is 'undefined'
      delete data[idName]
    else
      id = @getDefaultIdType()(idValue) if typeof idValue isnt @getDefaultIdType()
      data._key = id
      delete data[idName] if idName isnt '_key'

    aql = qb.insert('@data').in('@@collection').returnNew('inserted')
    bindVars =
      data: data,
      '@collection': @getCollectionName model


    @execute aql, bindVars, (err, result) ->
      return callback(err) if err

      idValue = result._result[0]._key
      modelClass = self._models[model]
      idType = modelClass.properties[idName].type

      if idType is Number
        num = Number(idValue)
        idValue = num if !isNaN(num)

      delete data._key
      data[idName] = idValue;
      callback err, idValue


  ###
    Save the model instance for the given data

    @param model [String] The model name
    @param data [Object] The updated data to save or create
    @param callback [Function] The callback function, called with a (possible) error object and the number of affected objects
  ###
  save: (model, data, options, callback) ->
    debug "save for #{model} with data: #{JSON.stringify data}" if @debug
    @updateOrCreate model, data, options, callback


  ###
    Update if the model instance exists with the same id or create a new instance

    @param model [String] The model name
    @param data [Object] The model instance data
    @param callback [Function] The callback function, called with a (possible) error object and updated or created object
  ###
  updateOrCreate: (model, data, options, callback) ->
    debug "updateOrCreate for Model #{model} with data: #{JSON.stringify data}" if @debug

    @getVersion (err, v) ->
      version = new RegExp(/[2-9]+\.[6-9]+\.[0-9]+/).test(v.version)
      if err or !version
        err = new Error "Error updateOrCreate not supported for version {#v}"
        callback err


    self = this
    idValue = @getIdValue(model, data)
    idName = @idName(model)
    idValue = String(idValue) if typeof idValue is 'number'
    delete data[idName]
    dataI = _.clone(data)
    dataI._key = idValue

    # RETURN statement at the moment is not supported
    # See https://github.com/arangodb/aqbjs/issues/15 when issue is solved
    #aql = qb.upsert({_key: '@id'}).insert('@dataI').update('@data').in('@@collection').return({doc: NEW, isNewInstance: OLD ? false : true })

    aql = 'UPSERT {_key: @id} INSERT @dataI UPDATE @data IN @@collection RETURN {doc: UNSET(NEW, ["_id", "_rev"]), isNewInstance: OLD ? false : true }'
    bindVars =
      '@collection': @getCollectionName model
      id: idValue
      dataI: dataI
      data: data

    @execute aql, bindVars, (err, result) ->
      if result and result._result[0]
        newDoc = result._result[0].doc
        isNewInstance = { isNewInstance: result._result[0].isNewInstance }
        self.setIdValue(model, data, newDoc._key)
        self.setIdValue(model, newDoc, newDoc._key)
        if idName isnt '_key' then delete newDoc._key
      callback err, newDoc, isNewInstance


  ###
    Check if a model instance exists by id

    @param model [String] The model name
    @param id [String] The id value
    @param callback [Function] The callback function, called with a (possible) error object and an boolean value if the specified object existed (true) or not (false)
  ###
  exists: (model, id, callback) ->
    debug "exists for #{model} with id: #{id}" if @debug

    @find model, id, (err, result) ->
      return callback err if err
      callback null, result._result.length > 0

  ###
    Find a model instance by id

    @param model [String] model The model name
    @param id [String] id The id value
    @param callback [Function] The callback function, called with a (possible) error object and the found object
  ###
  find: (model, id, callback) ->
    debug "find for #{model} with id: #{id}" if @debug

    aql = qb.for(@returnVariable).in('@@collection').filter(qb.eq( @returnVariable + '._key', '@id')).limit(1).return(qb.fn('UNSET') @returnVariable, ['"_id"','"_rev"'])

    bindVars =
      '@collection': @getCollectionName model
      id: id

    @execute aql, bindVars, (err, result) ->
      return callback err if err
      return callback null, result._result[0] if result._result.length > 0
      callback null, result._result


  # ========================
  # = Collection functions =
  # ========================
  ###
    Extracts where relevant information from the filter for a certain model
    @param [String] model The model name
    @param [Object] filter The filter object, also containing the where conditions
    @param [String] returnVariable The variable to build the where conditions on

    @return return [Object]
    @option return aqlArray [Array] The issued conditions as an array of AQL query builder objects
    @option return bindVars [Object] The variables, bound in the conditions
    @option return geoObject [Object] An query builder object containing possible parameters for a geo query
  ###
  _buildWhere: (model, where, index) ->
    debug "Evaluating where object #{JSON.stringify where} for Model #{model}" if @debug

    self = this

    if !where? or typeof where isnt 'object'
      return

    #  array holding the filter
    aqlArray = []
    #  the object holding the assignments of conditional values to temporary variables
    bindVars = {}

    geoExpr = {}

    # index for condition parameter binding
    index = index or 0

    #  helper function to fill bindVars with the upcoming temporary variables that the where sentence will generate
    assignNewQueryVariable = (value) ->
      partName = 'param_' + (index++)
      bindVars[partName] = value
      return '@'+partName

    idName = @idName(model)
    ###
      the where object comes in two flavors

       - where[prop] = value: this is short for "prop" equals "value"
       - where[prop][op] = value: this is the long version and stands for "prop" "op" "value"
    ###

    for condProp, condValue of where
      do() ->
        # correct if the conditionProperty falsely references to 'id'
        if condProp is idName
          condProp = '_key'
          if typeof condValue is 'number' then condValue = String(condValue)

        # special treatment for 'and', 'or' and 'nor' operator, since there value is an array of conditions
        if condProp in ['and', 'or', 'nor']
          # 'and', 'or' and 'nor' have multiple conditions so we run buildWhere recursively on their array to
          if Array.isArray condValue
            aql = qb
            # condValue is an array of conditions so get the conditions from it via a recursive buildWhere call
            for c, a of condValue
              cond = self._buildWhere model, a, ++index
              aql = aql[condProp] cond.aqlArray[0]
              bindVars = merge true, bindVars, cond.bindVars
            aqlArray.push aql
            aql = null
          return

        #  special case: if condValue is a Object (instead of a string or number) we have a conditionOperator
        if condValue and condValue.constructor.name is 'Object'
        #  condition operator is the only keys value, the new condition value is shifted one level deeper and can be a object with keys and values
          condOp = Object.keys(condValue)[0]
          condValue = condValue[condOp]

        if condOp
          # If the value is not an array, fall back to regular fields
          switch
            # number comparison
            when condOp in ['lte', 'lt', 'gte', 'gt', 'eq', 'neq']
              aqlArray.push qb[condOp] "#{self.returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"

            # range comparison
            when condOp is 'between'
              aqlArray.push [qb.gte("#{self.returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue[0])}"),  qb.lte("#{self.returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue[1])}")]

            # string comparison
            when condOp is 'like'
              aqlArray.push qb.not qb.LIKE "#{self.returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"
            when condOp is 'nlike'
              aqlArray.push qb.LIKE "#{self.returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"

            # array comparison
            when condOp is 'nin'
              aqlArray.push qb.not qb.in "#{self.returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"
            when condOp is 'inq'
              #TODO fix for id and other type
              condValue = (cond.toString() for cond in condValue)
              aqlArray.push qb.in "#{self.returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"

            # geo comparison (extra object)
            when condOp is 'near'
              # 'near' does not create a condition in the filter part, it returnes the lat/long pair
              # the query will be done from the querying method itself
              [lat, long] = condValue.split(',')
              collection = @getCollectionName model
              if where.limit?
                geoExpr = qb.NEAR collection, lat, long, where.limit
              else
                geoExpr = qb.NEAR collection, lat, long

            #  if we don't have a matching operator or no operator at all (condOp = false) print warning
            else
              console.warn 'No matching operatorfor : ', condOp
        else
          aqlArray.push qb.eq "#{self.returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"

    return {
      aqlArray: aqlArray
      bindVars: bindVars
      geoExpr: geoExpr
    }


  ###
    Find matching model instances by the filter

    @param [String] model The model name
    @param [Object] filter The filter
    @param [Function] callback Callback with (possible) error object or list of objects
  ###
  all: (model, filter, options, callback) ->
    debug "all for #{model} with filter #{JSON.stringify filter}" if @debug

    self = this
    idName = @idName(model)

    bindVars =
      '@collection': @getCollectionName model

    aql = qb.for(@returnVariable).in('@@collection')

    if filter.where
      if filter.where[idName]
        id = filter.where[idName];
        delete filter.where[idName];
        if typeof id is 'number' then id = String(id)
        filter.where._key = id;

      where = @_buildWhere(model, filter.where)
      for w in where.aqlArray
        aql = aql.filter(w)
      merge true, bindVars, where.bindVars

    if filter.order
      if typeof filter.order is 'string' then filter.order = filter.order.split(',')
      for order in filter.order
        m = order.match(/\s+(A|DE)SC$/)
        field = order.replace(/\s+(A|DE)SC$/, '').trim()
        if field is idName
          field = '_key'
        if m and m[1] is 'DE'
          aql = aql.sort(@returnVariable + '.' + field, 'DESC')
        else
          aql = aql.sort(@returnVariable + '.' + field, 'ASC')
    else
      aql = aql.sort(@returnVariable + '._key')

    if filter.limit
      aql = aql.limit(filter.skip, filter.limit)

    fields = _.clone(filter.fields)

    if fields
      indexId = fields.indexOf('id')
      if indexId isnt -1
        fields[indexId] = '_key'
      fields = ( '"' + field + '"' for field in fields)
      aql = aql.return(qb.fn('KEEP') @returnVariable, fields)
    else
      aql = aql.return((qb.fn('UNSET') @returnVariable, ['"_id"','"_rev"']))

    @execute aql, bindVars, (err, result) ->
      return callback err if err

      cursorToArray = (r) ->
        if _idIncluded(filter.fields, idName)
          self.setIdValue(model, r, r._key)
        # Don't pass back _key if the fields is set
        if idName isnt '_key' then delete r._key;

        r = self.fromDatabase(model, r)

      result = (cursorToArray r for r in result._result)

      # filter include
      if filter.include?
        self._models[model].model.include result, filter.include, options, callback
      else
        callback null, result


  ###
  Delete a model instance by id

  @param model [String] model The model name
  @param id [String] id The id value
  @param callback [Function] The callback function, called with a (possible) error object and the number of affected objects
  ###
  destroy: (model, id, callback) ->
    debug "delete for #{model} with id #{id}" if @debug

    aql = qb.for(@returnVariable).in('@@collection').filter(qb.eq(@returnVariable + '._key', '@id'))
    .remove(@returnVariable).in('@@collection').returnOld('removed')

    bindVars =
      '@collection': @getCollectionName model
      id: id


    @execute aql, bindVars, (err, result) ->
      res = result and result._result
      res.count = res.length
      callback and callback err, res


  ###
    Delete all instances for the given model

    @param [String] model The model name
    @param [Object] [where] The filter for where
    @param [Function] callback Callback with (possible) error object or the number of affected objects
  ###
  destroyAll: (model, where, callback) ->
    debug "destroyAll for #{model} with where #{JSON.stringify where}" if @debug

    collection = @getCollectionName model

    bindVars =
      '@collection': collection

    aql = qb.for(@returnVariable).in('@@collection')

    if !_.isEmpty(where)
      where = @_buildWhere model, where
      for w in where.aqlArray
        aql = aql.filter(w)
      merge true, bindVars, where.bindVars

    aql = aql.remove(@returnVariable).in('@@collection').returnOld('removed')

    @execute aql, bindVars, (err, result) ->
      return callback err if callback and err
      callback and callback err, {count: result._result.length}


  ###
    Count the number of instances for the given model

    @param [String] model The model name
    @param [Function] callback Callback with (possible) error object or the number of affected objects
    @param [Object] where The filter for where
  ###
  count: (model, where, options, callback) ->
    debug "count for #{model} with where #{JSON.stringify where}" if @debug

    collection = @getCollectionName model

    bindVars =
      '@collection': collection


    aql = qb.for(@returnVariable).in('@@collection')

    if !_.isEmpty(where)
      where = @_buildWhere model, where
      for w in where.aqlArray
        aql = aql.filter(w)
      merge true, bindVars, where.bindVars

    aql = aql.return(qb.fn('UNSET') @returnVariable, ['"_id"','"_rev"'])

    @execute aql, bindVars, (err, result) ->
      return callback err if err
      callback null, result._result.length


  ###
    Update properties for the model instance data

    @param [String] model The model name
    @param [String] id The models id
    @param [Object] data The model data
    @param [Function] callback Callback with (possible) error object or the updated object
  ###
  updateAttributes: (model, id, data, callback) ->
    debug "updateAttributes for #{model} with id #{id} and data #{JSON.stringify data}" if @debug

    self = this

    if id is Number then id = String(id)
    idName = @idName(model)

    bindVars =
      '@collection': @getCollectionName model
      id: id
      data: data

    #TODO: aqb not support _.return((qb.fn(UNSET) NEW, ['"_id"', '"_rev"']))
    aql = qb.for(@returnVariable).in('@@collection').filter(qb.eq(@returnVariable + '._key', '@id')).update(@returnVariable)
    .with('@data').in('@@collection').returnNew('updated')

    @execute aql, bindVars, (err, result) ->
      if result and result._result[0]
        result = result._result[0]
        delete result['_id']
        delete result['_rev']
        self.setIdValue(model, result, id);
        if idName isnt '_key' then delete result._key;
      callback and callback err, result


  ###
    Update all matching instances

    @param [String] model The model name
    @param [Object] where The search criteria
    @param [Object] data The property/value pairs to be updated
    @param [Function] callback Callback with (possible) error object or the number of affected objects
  ###
  update: (model, where, data, callback) ->
    @updateAll model, where, data, callback

  updateAll: (model, where, data, callback) ->
    debug "updateAll for #{model} with where #{JSON.stringify where} and data #{JSON.stringify data}" if @debug

    collection = @getCollectionName model

    bindVars =
      '@collection': collection
      data: data

    aql = qb.for(@returnVariable).in('@@collection')

    if where
      where = @_buildWhere(model, where)
      for w in where.aqlArray
        aql = aql.filter(w)
      merge true, bindVars, where.bindVars

    aql = aql.update(@returnVariable).with('@data').in('@@collection')

    idName = @idName(model)
    delete data[idName]

    @execute aql, bindVars, (err, result) ->
      return callback err if err
      callback null, {count: result.extra.stats.writesExecuted}

  # @extend require('./MigrationMixin')
  # ===================
  # = Migration Mixin =
  # ===================
  ###
    Perform autoupdate for the given models. It basically calls ensureIndex

    @param [String[]] [models] A model name or an array of model names. If not present, apply to all models
    @param [Function] [cb] The callback function
  ###
  autoupdate: (models, cb) ->

    self = this

    if @db
      debug 'autoupdate for model %s', models if @debug

      if (not cb) and (typeof models is 'function')
        cb = models
        models = undefined

      # First argument is a model name
      models = [models] if typeof models is 'string'

      models = models or Object.keys @_models

      async.each( models, ((model, modelCallback) ->
        indexes = self._models[model].settings.indexes or []
        indexList = []
        index = {}
        options = {}

        if typeof indexes is 'object'
          for indexName, index of indexes
            if index.keys
              # the index object has keys
              options = index.options or {}
              options.name = options.name or indexName
              index.options = options
            else
              options =
                name: indexName
              index =
                keys: index
                options: options

            indexList.push index
        else if Array.isArray indexes
          indexList = indexList.concat indexes

        for propIdx, property of self._models[model].properties
          if property.index
            index = {}
            index[propIdx] = 1

            if typeof property.index is 'object'
              # If there is a arangodb key for the index, use it
              if typeof property.index.arangodb is 'object'
                options = property.index.arangodb
                index[propIdx] = options.kind or 1
                # Backwards compatibility for former type of indexes
                options.unique = true if property.index.uniqe is true
              else
                # If there isn't an  properties[p].index.mongodb object, we read the properties from  properties[p].index
                options = property.index

              options.background = true if options.background is undefined

            # If properties[p].index isn't an object we hardcode the background option and check for properties[p].unique
            else
              options =
                background: true
              options.unique = true if property.unique

            indexList.push { keys: index, options: options }

        debug 'create indexes' if @debug

        async.each( indexList, ((index, indexCallback) ->
          debug 'createIndex: %s', index if @debug
          self.collection(model).createIndex(index.fields || index.keys, index.options, indexCallback);
        ), modelCallback )
      ), cb)
    else
      @dataSource.once 'connected', () -> @autoupdate models, cb



  ###
    Perform automigrate for the given models. It drops the corresponding collections and calls ensureIndex

    @param [String[]] [models] A model name or an array of model names. If not present, apply to all models
    @param [Function] [cb] The callback function
  ###
  automigrate: (models, cb) ->
    self = this

    if @db
      debug "automigrate for model #{models}" if @debug

      if (not cb) and (typeof models is 'function')
        cb = models
        models = undefined

      # First argument is a model name
      models = [models] if typeof models is 'string'

      models = models || Object.keys @_models

      async.eachSeries(models, ((model, modelCallback) ->
        collectionName = self.getCollectionName model
        debug 'drop collection %s for model %s', collectionName, model

        self.db.dropCollection model, (err, collection) ->
          if err
            if err.response.body?
              err = err.response.body
              #  For errors other than 'ns not found' (collection doesn't exist)
              return modelCallback err if not (err.error is true and err.errorNum is 1203 and err.errorMessage is 'unknown collection \'' + model + '\'')

          # Recreate the collection
          debug 'create collection %s for model %s', collectionName, model

          self.db.createCollection model, modelCallback

      ), ((err) ->
        return cb and cb err
        self.autoupdate models, cb
      ))
    else
      @dataSource.once 'connected', () -> @automigrate models cb


exports.ArangoDBConnector = ArangoDBConnector
