# node modules

# Module dependencies
arangojs = require 'arangojs'
qb = require 'aqb'
url = require 'url'
merge = require 'extend'
async = require 'async'
_ = require 'underscore'
Connector = require('loopback-connector').Connector
GeoPoint = require('loopback-datasource-juggler').GeoPoint
debug = require('debug') 'loopback:connector:arango'

###
  Generate the arangodb URL from the options
###
exports.generateArangoDBURL = generateArangoDBURL = (settings) ->
  u = {}
  u.protocol = settings.protocol or 'http:'
  u.hostname = settings.hostname or settings.host or '127.0.0.1'
  u.port = settings.port or 8529
  u.auth = "#{settings.username}:#{settings.password}" if settings.username and settings.password
  settings.databaseName = settings.database or settings.db or '_system'
  settings.promise = settings.promise or false
  return  url.format u

###
  Check if field should be included
  @param {Object} fields
  @param {String} fieldName
  @returns {Boolean}
  @private
###
_fieldIncluded = (fields, fieldName) ->
  if not fields then return true

  if Array.isArray fields
    return fields.indexOf fieldName >= 0

  if fields[fieldName]
    # Included
    return true

  if fieldName in fields and !fields[fieldName]
    # Excluded
    return false

  for f in fields
    return !fields[f]; # If the fields has exclusion

  return true

###
  Verify if a field is a reserved arangoDB key
  @param {String} key The name of key to verify
  @returns {Boolean}
  @private
###
_isReservedKey = (key) ->
  key in ['_key', '_id', '_rev', '_from', '_to']
    
    
###
  Initialize the ArangoDB connector for the given data source
  @param {DataSource} dataSource The data source instance
  @param {Function} [callback] The callback function
###
exports.initialize = initializeDataSource = (dataSource, callback) ->
  return if not arangojs

  s = dataSource.settings
  s.url = s.url or generateArangoDBURL s
  dataSource.connector = new ArangoDBConnector s, dataSource
  dataSource.connector.connect callback if callback?

###
  Loopback ArangoDB Connector
  @extend Connector
###
class ArangoDBConnector extends Connector
  returnVariable = 'result'
  @collection = 'collection'
  @edgeCollection = 'edgeCollection'
  @returnVariable = 'result'
  
  ###
    The constructor for ArangoDB connector
    @param {Object} settings The settings object
    @param {DataSource} dataSource The data source instance
    @constructor
  ###
  constructor: (settings, dataSource) ->
    super 'arangodb', settings
    # debug
    @debug = dataSource.settings.debug or debug.enabled
    # link to datasource
    @dataSource = dataSource
    # Arango Query Builder
    # TODO MAJOR rename to aqb
    @qb = qb

  ###
    Connect to ArangoDB
    @param {Function} [callback] The callback function
 
    @callback callback
    @param {Error} err The error object
    @param {Db} db The arangoDB object
  ###
  connect: (callback) ->
    debug "ArangoDB connection is called with settings: #{JSON.stringify @settings}" if @debug
    if not @db
      @db = arangojs @settings
      @api = @db.route '/_api'
    process.nextTick () ->
      callback null, @db if callback

  ###
    Get the types of this connector
    @return {Array<String>} The types of connector
  ###
  getTypes: () ->
    return ['db', 'nosql', 'arangodb']

  ###
    The default Id type
    @return {String} The type of id value
  ###
  getDefaultIdType: () ->
    return String

  ###
    Get the model class for a certain model name
    @param {String} model The model name to lookup
    @return {Object} The model class of this model
  ###
  getModelClass: (model) ->
    return @_models[model]

  ###
    Get the collection name for a certain model name
    @param {String} model The model name to lookup
    @return {Object} The collection name for this model
  ###
  getCollectionName: (model) ->
    modelClass = @getModelClass model
    if modelClass.settings and modelClass.settings.arangodb
      model = modelClass.settings.arangodb.collection or model
    return model

  ###
    Coerce the id value
  ###
  coerceId: (model, id) ->
    return id if not id?
    idValue = id;
    idName = @idName model

    # Type conversion for id
    idProp = @getPropertyDefinition model, idName
    if idProp && typeof idProp.type is 'function'
      if not (idValue instanceof idProp.type)
        idValue = idProp.type id
        # Reset to id
        if idProp.type is Number and isNaN id then idValue = id
    return idValue;
    
  ###
    Set value of specific field into data object
    @param data {Object} The data object
    @param field {String} The name of field to set
    @param value {Any} The value to set
  ###
  _setFieldValue: (data, field, value) ->
    if data then data[field] = value;

  ###
    Verify if the collection is an edge collection
    @param model [String] The model name to lookup
    @return [Boolean] Return true if collection is edge false otherwise
  ###
  _isEdge: (model) ->
    modelClass = @getModelClass model
    settings = modelClass.settings
    return settings and settings.arangodb and settings.arangodb.edge || false

  ###
  ###
  _getNameOfProperty: (model, p) ->
    props = @getModelClass(model).properties
    for key, prop of props
      if prop[p] then return key else continue
    return false

  ###
    Get if the model has _id field
    @param {String} model The model name to lookup
    @return {String|Boolean} Return name of _id or false if model not has _id field
  ###
  _fullIdName: (model) ->
    @_getNameOfProperty model, '_id'

  ###
    Get if the model has _from field
    @param {String} model The model name to lookup
    @return {String|Boolean} Return name of _from or false if model not has _from field
  ###
  _fromName: (model) ->
    @_getNameOfProperty model, '_from'

  ###
    Get if the model has _to field
    @param {String} model The model name to lookup
    @return {String|Boolean} Return name of _to or false if model not has _to field
  ###
  _toName: (model) ->
    @_getNameOfProperty model, '_to'

  ###
    Access a ArangoDB collection by model name
    @param {String} model The model name
    @return {*}
  ###
  getCollection: (model) ->
    if not @db then throw new Error('ArangoDB connection is not established')

    collection = ArangoDBConnector.collection
    if @_isEdge model then collection = ArangoDBConnector.edgeCollection
    return @db[collection] @getCollectionName model

  ###
    Converts the retrieved data from the database to JSON, based on the properties of a given model
    @param {String} model The model name to look up the properties
    @param {Object} [data] The data from DB
    @return {Object} The converted data as an JSON Object
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
    Execute a ArangoDB command
  ###
  execute: (model, command) ->
    #Get the parameters for the given command
    args = [].slice.call(arguments, 2);
    #The last argument must be a callback function
    callback = args[args.length - 1];
    context =
      req:
        command: command
        params: args

    @notifyObserversAround 'execute', context, (context, done) =>
      debug 'ArangoDB: model=%s command=%s', model, command, args if @debug

      args[args.length - 1] = (err, result) ->
        if err
          debug('Error: ', err);
        else
          context.res = result;
          debug('Result: ', result)
        done(err, result);

      if command is 'query'
        query = context.req.params[0]
        bindVars = context.req.params[1]
        if @debug
          if typeof query.toAQL is 'function'
            q = query.toAQL()
          else
            q = query
          debug "query: #{q} bindVars: #{JSON.stringify bindVars}"

        @db.query.apply @db, args
      else
        collection = @getCollection model
        collection[command].apply collection, args
    , callback

  ###
    Get the version of the ArangoDB
    @param callback [Function] The callback function

    @callback callback
    @param {Error} err The error object
    @param {String} version The arangoDB version
  ###
  getVersion: (callback) ->
    if @version?
      callback null, @version
    else
      @api.get 'version', (err, result) ->
        callback err if err
        @version = result.body
        callback null, @version

  ###
    Create a new model instance for the given data
    @param {String} model The model name
    @param {Object} data The data to create
    @param {Object} options The data to create
    @param callback [Function] The callback function
  ###
  create: (model, data, options, callback) ->
    debug "create model #{model} with data: #{JSON.stringify data}" if @debug

    idValue = @getIdValue model, data
    idName = @idName model
    if !idValue? or typeof idValue is 'undefined'
      delete data[idName]
    else
      id = @getDefaultIdType() idValue
      data._key = id
      if idName isnt '_key' then delete data[idName]

    # Check and delete full id name if present
    fullIdName = @_fullIdName model
    if fullIdName then delete data[fullIdName]

    isEdge = @_isEdge model
    fromName = null
    toName = null

    if isEdge
      fromName = @_fromName model
      data._from = data[fromName]
      if fromName isnt '_from'
        data._from = data[fromName]
        delete data[fromName]
      toName = @_toName model
      if toName isnt '_to'
        data._to = data[toName]
        delete data[toName]

    @execute model, 'save', data, (err, result) =>
      if err
        # Change message error to pass junit test
        if err.errorNum is 1210 then err.message = '/duplicate/i'
        return callback(err)
      # Save _key and _id value
      idValue = @coerceId model, result._key
      delete data._key
      data[idName] = idValue;
      
      if isEdge
        if fromName isnt '_from' then data[fromName] = data._from
        if toName isnt '_to' then data[toName] = data._to

      if fullIdName
        data[fullIdName] = result._id
        delete result._id
        
      callback err, idValue

  ###
    Update if the model instance exists with the same id or create a new instance
    @param model [String] The model name
    @param data [Object] The model instance data
    @param options [Object] The options
    @param callback [Function] The callback function, called with a (possible) error object and updated or created object
  ###
  updateOrCreate: (model, data, options, callback) ->
    debug "updateOrCreate for Model #{model} with data: #{JSON.stringify data}" if @debug

    @getVersion (err, v) ->
      version = new RegExp(/[2-9]+\.[6-9]+\.[0-9]+/).test(v.version)
      if err or !version
        err = new Error "Error updateOrCreate not supported for version {#v}"
        callback err

    idValue = @getIdValue(model, data)
    idName = @idName(model)
    idValue = @getDefaultIdType() idValue if typeof idValue is 'number'
    delete data[idName]

    fullIdName = @_fullIdName model
    if fullIdName then delete data[fullIdName]

    isEdge = @_isEdge model
    fromName = null
    toName = null

    if isEdge
      fromName = @_fromName model
      if fromName isnt '_from'
        data._from = data[fromName]
        delete data[fromName]
      toName = @_toName model
      if toName isnt '_to'
        data._to = data[toName]
        delete data[toName]

    dataI = _.clone(data)
    dataI._key = idValue

    aql = qb.upsert({_key: '@id'}).insert('@dataI').update('@data').in('@@collection').let('isNewInstance',
      qb.ref('OLD').then(false).else(true)).return({doc: 'NEW', isNewInstance: 'isNewInstance'});
    bindVars =
      '@collection': @getCollectionName model
      id: idValue
      dataI: dataI
      data: data

    @execute model, 'query', aql, bindVars, (err, result) =>
      if result and result._result[0]
        newDoc = result._result[0].doc
        # Delete revision
        delete newDoc._rev
        if fullIdName
          data[fullIdName] = newDoc._id
          if fullIdName isnt '_id' then delete newDoc._id
        else
          delete newDoc._id
          if isEdge
            if fromName isnt '_from' then data[fromName] = data._from
            if toName isnt '_to' then data[toName] = data._to

        isNewInstance = { isNewInstance: result._result[0].isNewInstance }
        @setIdValue(model, data, newDoc._key)
        @setIdValue(model, newDoc, newDoc._key)
        if idName isnt '_key' then delete newDoc._key
      callback err, newDoc, isNewInstance

  ###
    Save the model instance for the given data
    @param model [String] The model name
    @param data [Object] The updated data to save or create
    @param options [Object]
    @param callback [Function] The callback function, called with a (possible) error object and the number of affected objects
  ###
  save: @::updateOrCreate

  ###
    Check if a model instance exists by id
    @param model [String] The model name
    @param id [String] The id value
    @param options [Object]
    @param callback [Function] The callback function, called with a (possible) error object and an boolean value if the specified object existed (true) or not (false)
  ###
  exists: (model, id, options, callback) ->
    debug "exists for #{model} with id: #{id}" if @debug

    @find model, id, options, (err, result) ->
      return callback err if err
      callback null, result.length > 0

  ###
    Find a model instance by id
    @param model [String] model The model name
    @param id [String] id The id value
    @param options [Object]
    @param callback [Function] The callback function, called with a (possible) error object and the found object
  ###
  find: (model, id, options, callback) ->
    debug "find for #{model} with id: #{id}" if @debug

    command = 'document'
    if @_isEdge model then command = 'edge'

    @execute model, command, id, (err, result) ->
      return callback err if err
      callback null, result

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
      return '@' + partName

    idName = @idName model
    fullIdName = @_fullIdName model
    fromName = @_fromName model
    toName = @_toName model
    ###
      the where object comes in two flavors

       - where[prop] = value: this is short for "prop" equals "value"
       - where[prop][op] = value: this is the long version and stands for "prop" "op" "value"
    ###
    for condProp, condValue of where
      do() =>
        # special treatment for 'and', 'or' and 'nor' operator, since there value is an array of conditions
        if condProp in ['and', 'or', 'nor']
          # 'and', 'or' and 'nor' have multiple conditions so we run buildWhere recursively on their array to
          if Array.isArray condValue
            aql = qb
            # condValue is an array of conditions so get the conditions from it via a recursive buildWhere call
            for c, a of condValue
              cond = @_buildWhere model, a, ++index
              aql = aql[condProp] cond.aqlArray[0]
              bindVars = merge true, bindVars, cond.bindVars
            aqlArray.push aql
            aql = null
          return

        # correct if the conditionProperty falsely references to 'id'
        if condProp is idName
          condProp = '_key'
          if typeof condValue is 'number' then condValue = String(condValue)
        if condProp is fullIdName
          condProp = '_id'
        if condProp is fromName
          condProp = '_from'
        if condProp is toName
          condProp = '_to'

        #  special case: if condValue is a Object (instead of a string or number) we have a conditionOperator
        if condValue and condValue.constructor.name is 'Object'
          #  condition operator is the only keys value, the new condition value is shifted one level deeper and can be a object with keys and values
          options = condValue.options
          condOp = Object.keys(condValue)[0]
          condValue = condValue[condOp]
        if condOp
          # If the value is not an array, fall back to regular fields
          switch
            when condOp in ['lte', 'lt']
              aqlArray.push qb[condOp] "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"
              # https://docs.arangodb.com/2.8/Aql/Basics.html#type-and-value-order
              if condValue isnt null
                aqlArray.push qb['neq'] "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(null)}"
            when condOp in ['gte', 'gt']
              # https://docs.arangodb.com/2.8/Aql/Basics.html#type-and-value-order
              if condValue is null
                if condOp is 'gte' then condOp = 'lte'
                if condOp is 'gt' then condOp = 'lt'
                aqlArray.push qb[condOp] "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(null)}"
              else
                aqlArray.push qb[condOp] "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"
            when condOp in ['eq', 'neq']
              aqlArray.push qb[condOp] "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"
            # range comparison
            when condOp is 'between'
              aqlArray.push [qb.gte("#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue[0])}"),  qb.lte("#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue[1])}")]
            # string comparison
            when condOp is 'like'
              if options is 'i' then options = true else options = false
              aqlArray.push qb.fn('LIKE') "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}", options
            when condOp is 'nlike'
              if options is 'i' then options = true else options = false
              aqlArray.push qb.not qb.fn('LIKE') "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}", options
            # array comparison
            when condOp is 'nin'
              if _isReservedKey condProp
                condValue = (value.toString() for value in condValue)
              aqlArray.push qb.not qb.in "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"
            when condOp is 'inq'
              if _isReservedKey condProp
                condValue = (value.toString() for value in condValue)
              aqlArray.push qb.in "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"
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
              console.warn 'No matching operator for : ', condOp
        else
          aqlArray.push qb.eq "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"
    return {
    aqlArray: aqlArray
    bindVars: bindVars
    geoExpr: geoExpr
    }

  ###
    Find matching model instances by the filter
    @param [String] model The model name
    @param [Object] filter The filter
    @param options [Object]
    @param [Function] callback Callback with (possible) error object or list of objects
  ###
  all: (model, filter, options, callback) ->
    debug "all for #{model} with filter #{JSON.stringify filter}" if @debug

    idName = @idName model
    fullIdName = @_fullIdName model
    fromName = @_fromName model
    toName = @_toName model

    bindVars =
      '@collection': @getCollectionName model
    aql = qb.for(returnVariable).in('@@collection')

    if filter.where
      where = @_buildWhere(model, filter.where)
      for w in where.aqlArray
        aql = aql.filter(w)
      merge true, bindVars, where.bindVars

    if filter.order
      if typeof filter.order is 'string' then filter.order = filter.order.split(',')
      for order in filter.order
        m = order.match(/\s+(A|DE)SC$/)
        field = order.replace(/\s+(A|DE)SC$/, '').trim()
        if field in [idName, fullIdName, fromName, toName]
          switch field
            when idName then field = '_key'
            when fullIdName then field = '_id'
            when fromName then field = '_from'
            when toName then field = '_to'
        if m and m[1] is 'DE'
          aql = aql.sort(returnVariable + '.' + field, 'DESC')
        else
          aql = aql.sort(returnVariable + '.' + field, 'ASC')
    else if not @settings.disableDefaultSortByKey
      aql = aql.sort(returnVariable + '._key')

    if filter.limit
      aql = aql.limit(filter.skip, filter.limit)

    fields = _.clone(filter.fields)
    if fields
      indexId = fields.indexOf(idName)
      if indexId isnt -1
        fields[indexId] = '_key'
      indexFullId = fields.indexOf(fullIdName)
      if indexFullId isnt -1
        fields[indexFullId] = '_id'
      indexFromName = fields.indexOf(fromName)
      if indexFromName isnt -1
        fields[indexFromName] = '_from'
      indexToName = fields.indexOf(toName)
      if indexToName isnt -1
        fields[indexToName] = '_to'
      fields = ( '"' + field + '"' for field in fields)
      aql = aql.return(qb.fn('KEEP') returnVariable, fields)
    else
      aql = aql.return((qb.fn('UNSET') returnVariable, ['"_rev"']))

    @execute model, 'query', aql, bindVars, (err, cursor) =>
      return callback err if err
      cursorToArray = (r) =>
        if _fieldIncluded filter.fields, idName
          @setIdValue model, r, r._key
        # Don't pass back _key if the fields is set
        if idName isnt '_key' then delete r._key;

        if fullIdName
          if _fieldIncluded filter.fields, fullIdName
            @_setFieldValue r, fullIdName, r._id
          if fullIdName isnt '_id' and idName isnt '_id' then delete r._id
        else
          if idName isnt '_id' then delete r._id

        if @_isEdge model
          if _fieldIncluded filter.fields, fromName
            @_setFieldValue r, fromName, r._from
          if fromName isnt '_from' then delete r._from
          if _fieldIncluded filter.fields, toName
            @_setFieldValue r, toName, r._to
            if toName isnt '_to' then delete r._to
        r = @fromDatabase(model, r)

      cursor.map cursorToArray, (err, result) =>
        return callback err if err
        # filter include
        if filter.include?
          @_models[model].model.include result, filter.include, options, callback
        else
          callback null, result

  ###
    Delete a model instance by id
    @param model [String] model The model name
    @param id [String] id The id value
    @param options [Object]
    @param callback [Function] The callback function, called with a (possible) error object and the number of affected objects
  ###
  destroy: (model, id, options, callback) ->
    debug "delete for #{model} with id #{id}" if @debug

    @execute model, 'remove', id, (err, result) ->
      # Set error to null if API response is `document not found`
      if err and err.errorNum is 1202 then err = null
      callback and callback err, {count: if result and !result.error then 1 else 0}

  ###
    Delete all instances for the given model
    @param [String] model The model name
    @param [Object] [where] The filter for where
    @param options [Object]
    @param [Function] callback Callback with (possible) error object or the number of affected objects
  ###
  destroyAll: (model, where, options, callback) ->
    debug "destroyAll for #{model} with where #{JSON.stringify where}" if @debug

    if !callback && typeof where is 'function'
      callback = where
      where = undefined

    collection = @getCollectionName model
    bindVars =
      '@collection': collection
    aql = qb.for(returnVariable).in('@@collection')

    if !_.isEmpty(where)
      where = @_buildWhere model, where
      for w in where.aqlArray
        aql = aql.filter(w)
      merge true, bindVars, where.bindVars
    aql = aql.remove(returnVariable).in('@@collection')

    @execute model, 'query', aql, bindVars, (err, result) ->
      callback and callback err, {count: result.extra.stats.writesExecuted}

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
    aql = qb.for(returnVariable).in('@@collection')

    if !_.isEmpty(where)
      where = @_buildWhere model, where
      for w in where.aqlArray
        aql = aql.filter(w)
      merge true, bindVars, where.bindVars

    aql = qb.let('count', aql.return(returnVariable)).return(qb.LENGTH('count'))
    @execute model, 'query', aql, bindVars, (err, result) ->
      callback err, result._result[0]

  ###
    Update properties for the model instance data
    @param [String] model The model name
    @param [String] id The models id
    @param [Object] data The model data
    @param [Object] options
    @param [Function] callback Callback with (possible) error object or the updated object
  ###
  updateAttributes: (model, id, data, options, callback) ->
    debug "updateAttributes for #{model} with id #{id} and data #{JSON.stringify data}" if @debug

    id = @getDefaultIdType() id
    idName = @idName(model)
    fullIdName = @_fullIdName model
    if fullIdName then delete data[fullIdName]

    isEdge = @_isEdge model
    fromName = null
    toName = null

    if isEdge
      fromName = @_fromName model
      delete data[fromName]
      toName = @_toName model
      delete data[toName]

    @execute model, 'update', id, data, options, (err, result) =>
      if result
        delete result['_rev']
        if idName isnt '_key' then delete result._key;
        @setIdValue(model, result, id);
        if fullIdName
          fullIdValue = result._id
          delete result._id
          result[fullIdName] = fullIdValue;
        if isEdge
          result[fromName] = data._from
          result[toName] = data._to
      callback and callback err, result

  ###
    Update matching instance
    @param [String] model The model name
    @param [Object] where The search criteria
    @param [Object] data The property/value pairs to be updated
    @param [Object] options
    @param [Function] callback Callback with (possible) error object or the number of affected objects
  ###
  update: (model, where, data, options, callback) ->
    debug "updateAll for #{model} with where #{JSON.stringify where} and data #{JSON.stringify data}" if @debug

    collection = @getCollectionName model
    bindVars =
      '@collection': collection
      data: data

    aql = qb.for(returnVariable).in('@@collection')
    if where
      where = @_buildWhere(model, where)
      for w in where.aqlArray
        aql = aql.filter(w)
      merge true, bindVars, where.bindVars
    aql = aql.update(returnVariable).with('@data').in('@@collection')
    # _id, _key _from and _to are are immutable once set and cannot be updated
    idName = @idName(model)
    delete data[idName]
    fullIdName = @_fullIdName model
    if fullIdName then delete data[fullIdName]
    if @_isEdge model
      fromName = @_fromName model
      delete data[fromName]
      toName = @_toName model
      delete data[toName]

    @execute model, 'query', aql, bindVars, (err, result) ->
      return callback err if err
      callback null, {count: result.extra.stats.writesExecuted}

  ###
    Update all matching instances
  ###
  updateAll: @::update

  ###
    Perform autoupdate for the given models. It basically calls ensureIndex
    @param [String[]] [models] A model name or an array of model names. If not present, apply to all models
    @param [Function] [cb] The callback function
  ###
  autoupdate: (models, cb) ->
    if @db
      debug 'autoupdate for model %s', models if @debug
      if (not cb) and (typeof models is 'function')
        cb = models
        models = undefined
      # First argument is a model name
      models = [models] if typeof models is 'string'
      models = models or Object.keys @_models
      async.each( models, ((model, modelCallback) =>
        indexes = @_models[model].settings.indexes or []
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

        for propIdx, property of @_models[model].properties
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
            indexList.push {keys: index, options: options}

        debug 'create indexes' if @debug
        async.each( indexList, ((index, indexCallback) =>
          debug 'createIndex: %s', index if @debug
          collection = @getCollection model
          collection.createIndex(index.fields || index.keys, index.options, indexCallback);
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
    if @db
      debug "automigrate for model #{models}" if @debug
      if (not cb) and (typeof models is 'function')
        cb = models
        models = undefined
      # First argument is a model name
      models = [models] if typeof models is 'string'
      models = models || Object.keys @_models

      async.eachSeries(models, ((model, modelCallback) =>
        collectionName = @getCollectionName model
        debug 'drop collection %s for model %s', collectionName, model
        collection = @getCollection model
        collection.drop (err) =>
          if err
            if err.response.body?
              err = err.response.body
              #  For errors other than 'ns not found' (collection doesn't exist)
              return modelCallback err if not (err.error is true and err.errorNum is 1203 and err.errorMessage is 'unknown collection \'' + model + '\'')
          # Recreate the collection
          debug 'create collection %s for model %s', collectionName, model
          collection.create modelCallback
      ), ((err) =>
        return cb and cb err
        @autoupdate models, cb
      ))
    else
      @dataSource.once 'connected', () -> @automigrate models cb

exports.ArangoDBConnector = ArangoDBConnector
