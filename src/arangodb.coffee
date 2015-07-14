# node modules
url = require 'url'

# 3rd party modules
debug = require('debug') 'loopback:connector:arango:main_class'
merge = require 'extend'
_ = require 'underscore'
Connector = require('loopback-connector').Connector
GeoPoint = require('loopback-datasource-juggler').GeoPoint

# arango
ajs = require 'arangojs'
qb = require 'aqb'

generateConnObject = (settings) ->
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

  config = {
    url: dbUrl
    databaseName: database
    promise: promise
  }

  return config


exports.generateConnObject = generateConnObject
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
    debug 'constructor called' if @debug


    # link to datasource
    @dataSource = dataSource


    # Query builder
    @qb = require('aqb')

    @db = require('arangojs') @settings
    @api = @db.route '_api'

  # one file per functionality
  # @extend require('./CoreMixin')
  # =============
  # = CoreMixin =
  # =============
  ###
    Connect to ArangoDB

    @param callback [Function] The callback function, called the with created connection
  ###
  connect: (callback) =>
    debug 'connect called' if @debug
    process.nextTick () ->
      callback && callback null, @db

  ###
    Get the types of this connector

    @return [Array<String>] The types of connectors this connector belongs to
  ###
  getTypes: () =>
    return ['db', 'nosql', 'arangodb']


  ###
    The default Id type

    @return [Object] The class to build the Id Value with

  ###
  getDefaultIdType: () =>
    return String

  ###
    Get the model class for a certain model name

    @param model [String] The model name to lookup

    @return [Object] The model class of this model
  ###
  getModelClass: (model) =>
    return @_models[model]


  ###
    Get the collection name for a certain model name

    @param model [String] The model name to lookup

    @return [Object] The collection name for this model
  ###
  getCollectionName: (model) =>
    if @getModelClass(model).settings.options?.arangodb?
      model = @getModelClass(model).settings.options?.arangodb?.collection or model

    return model


  ###
    Converts the retrieved data from the database to JSON, based on the properties of a given model

    @param model [String] The model name to look up the properties
    @param data [Object] The data from DB

    @return [Object] The converted data as an JSON Object
  ###
  fromDatabase: (model, data) =>
    return null if not data?

    properties = @getModelClass(model).properties

    for key, val of data
      # change _key value to an id property and then delete _id (database wide doc handle) and _key (collection wide doc handle)
      if key in ['_key', '_id']
        data.id = switch
          when key is '_key' then val
          when key is '_id' then val.split('/')[0]
        delete data[key]
        continue

      # Buffer
      if properties[key]?.type is Buffer and val?
        data[key] = new Buffer(val, 'base64')

      # TODO: Look how to read ArangoDB binary data into a buffer
      # if properties[key]?.type is Buffer and val?
      #   #from binary
      #   if(data[p] instanceof mongodb.Binary) [
      #     // Convert the Binary into Buffer
      #     data[p] = data[p].read(0, data[p].length());
      #   ]

      # String
      # if properties[key]?.type is String and val?
      #   # from binary
      #   if(data[p] instanceof mongodb.Binary) [
      #     // Convert the Binary into String
      #     data[p] = data[p].toString();
      #   ]

      # Date
      if properties[key]?.type is Date and val?
        data[key] = new Date val

      # GeoPoint
      if properties[key]?.type is GeoPoint and val?
        data[key] = new GeoPoint { lat: val.lat, lng: val.lng }

      # TODO: still to come: Boolean, Number, Array and any arbitrary type

    return data



  ###
    Converts JSON to insert into the database, based on the properties of a given model

    @param model [String] The model name to look up the properties
    @param data [Object] The JSON object to transferred to the database

    @return [Object] The converted data as an Plain Javascript Object
  ###
  toDatabase: (model, data) =>
    return null if not data?

    properties = @getModelClass(model).properties

    for key, val of data
      # change _key value to an id property and then delete _id (database wide doc handle) and _key (collection wide doc handle)
      if key in ['_key', '_id']
        data.id = switch
          when key is '_key' then val
          when key is '_id' then val.split('/')[0]
        delete data[key]
        continue

      # Buffer
      if properties[key]?.type is Buffer and val?
        data[key] = val.toString('base64')

      # Date
      if properties[key]?.type is Date and val?
        data[key] = new Date val

      # GeoPoint
      if properties[key]?.type is GeoPoint and val?
        data[key] = val

      # TODO: still to come: Boolean, Number, Array and any arbitrary type

    return data



  ###
    Transaction

    @param collections [Object|Array|String] collection(s) to lock
    @param action [String] Function to evaluate
    @param params [Object] Parameter to call the action function with
    @param callback [Function] The callback function, called with a (possible) error object and the transactions result
  ###
  transaction: (collections, action, params, callback) =>
    # empty params by default
    params = params or []

    # evaluate action to a string, if not already one
    # TODO: examine if function, make sure that when there is a params parameter function has the same param count in numbers
    action = if typeof action isnt String then String(action) else action

    @db.transaction collections, action, params, (err, result) ->
      callback err if err
      callback null, result

  ###
    Query with AQL and binded variables

    @param query [String|Object] The AQL query to execute
    @param bindVars [Object] The variables bound to the AQL query
    @param callback [Function] The callback function, called with a (possible) error object and the query's cursor
  ###
  query: (query, bindVars, callback) =>
    # TODO: if query is instance of AQB use query.toAQL() to print readable AQL query
    debug 'query', query, bindVars if @debug

    if typeof bindVars is 'function'
      callback = bindVars
      bindVars = {}

    @db.query query, bindVars, (err, cursor) ->
      # workaround: when there is no error (e.g. wrong AQL syntax etc.) and no cursor, the authentication failed
      if not err? and cursor.length = 0
        authErr = new Error 'Authentication failed'
        callback authErr, null
      else
        callback err, cursor


  ###
    Checks the version of the ArangoDB

    @param callback [Function] The calback function, called with a (possible) error object and the server versio
  ###
  getVersion: (callback) =>
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
  create: (model, data, callback) =>
    debug 'create', model, data if @debug

    aql = qb.insert('@data').in(@getCollectionName(model)).returnNew('inserted')
    bindVars = {
      data: data
    }

    @query aql, bindVars, (err, result) ->
      callback err if err
      callback null, result._result[0]._key

  ###
    Save the model instance for the given data

    @param model [String] The model name
    @param data [Object] The updated data to save or create
    @param callback [Function] The callback function, called with a (possible) error object and the number of affected objects
  ###
  save: (model, data, callback) =>
    debug 'save', model, data if @debug
    @_updateOrCreate model, data, true, (err, result) ->
      callback err if err
      callback null, result.length

  ###
    Update if the model instance exists with the same id or create a new instance
    # TODO: change this to UPSERT AQL when 2.6 is out

    @param model [String] The model name
    @param data [Object] The model instance data
    @param callback [Function] The callback function, called with a (possible) error object and updated or created object
  ###
  _updateOrCreate: (model, data, callback) =>
    debug 'updateOrCreate', model, data if @debug

    id = data.id
    delete data.id

    update_aql = qb.update('@id').with('@data').in('@@collection').returnNew('updated').toAQL()
    create_aql = qb.insert('@data').in('@@collection').returnNew('inserted').toAQL()

    # the trans-action ;)
    action = (params) ->
      db = require('internal').db
      # try to update and return if we have an result
      update_params = [ id: params.id, data: params.data, collection: params.collection ]
      update_query = db._query(update_aql, update_params).toArray()
      return update_result[0] if update_result.length > 0

      # if update failed we try to create it
      create_params = [ data: params.data, collection: params.collection ]
      create_result = db._query(create_aql, create_params).toArray()

      throw create_result if (create_result instanceof Error)

      return create_result[0] if create_result.length > 0
      return create_result


    @transaction @getCollectionName(model), action, { id: id, data: data, collection: @getCollectionName(model) }, (err, result) ->
      callback err if err
      callback null, result

  updateOrCreate: (model, data, callback) =>
    @_updateOrCreate model, data, (err, result) ->
      callback err if err
      callback result[0] if result.length > 0
      callback result


  ###
    Check if a model instance exists by id

    @param model [String] The model name
    @param id [String] The id value
    @param callback [Function] The callback function, called with a (possible) error object and an boolean value if the specified object existed (true) or not (false)
  ###
  exists: (model, id, callback) =>
    debug 'create', model, data if @debug

    @find model, id, (err, result) ->
      callback err if err
      callback null, (result.length > 0)

  ###
    Find a model instance by id

    @param model [String] model The model name
    @param id [String] id The id value
    @param callback [Function] The callback function, called with a (possible) error object and the found object
  ###
  find: (model, id, callback) =>
    debug 'find', model, id if @debug

    aql = qb.for('retDoc').in('@@collection').filter(qb.eq("retDoc._key", '@id')).limit(1).return('retDoc')
    bindVars = {
      collection: @getCollectionName(model),
      id: id
    }

    @query aql, bindVars, (err, result) ->
      callback err if err
      callback null, result[0] if result.length > 0
      callback null, result

  ###
    Delete a model instance by id

    @param model [String] model The model name
    @param id [String] id The id value
    @param callback [Function] The callback function, called with a (possible) error object and the number of affected objects
  ###
  destroy: (model, id, callback) =>
    debug 'delete', model, id if @debug

    aql = qb.for('removeDoc').in('@@collection').filter(qb.eq('removeDoc._key', '@id')).returnOld('removed')
    bindVars = {
      collection: @getCollectionName(model)
      id: id
    }

    @query aql, bindVars, (err, result) ->
      callback err if err
      callback null, result[0] if result.length > 0
      callback null, result

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
  _filter2where: (model, filter, returnVariable) =>
    debug "#[model]: Evaluating where object #[JSON.stringify where]" if @debug

    # variable to name the result
    returnVariable = returnVariable or 'result'
    #  the object holding the assignments of conditional values to temporary variables
    boundVars = {}
    # index for condition parameter binding
    index = 0
    #  helper function to fill boundVars with the upcoming temporary variables that the where sentence will generate
    assignNewQueryVariable = (value) ->
      partName = 'param_' + (index++)
      boundVars[partName] = value
      return '@'+partName

    #  array holding the filter
    aqlArray = []
    ###
      the where object comes in two flavors

       - where[prop] = value: this is short for "prop" equals "value"
       - where[prop][op] = value: this is the long version and stands for "prop" "op" "value"
    ###
    for condProp, condValue of filter.where

      # correct if the conditionProperty falsely references to 'id'
      condProp = '_key' if condProp is 'id'

      #  special case: if conditionValue is a Object (instead of a string or number) we have a conditionOperator
      if condValue and condValue.constructor.name is 'Object'
        #  condition operator is the only keys value, the new condition value is shifted one level deeper and can be a object with keys and values
        condOp = Object.keys(condValue)[0]
        condValue = condValue[condOp]
      else
        # condition operator is 'equals' or shortly 'eq'
        # and condition value is stringified for the comparison
        condOp = 'eq'
        condValue = condValue.toString()

      # special treatment for "and" and "or" operator, since there value is an array of conditions
      if condOp in ['and', 'or']
        # 'and' and 'or' have multiple conditions so we run buildWhere recursively on their array to
        if _.isArray condValue
          # condValue is an array of conditions so get the conditions from it via a recursive buildWhere call
          conditionalPart = @_filter2where model, condValue, returnVariable

          # add the condArray resp. the boundVars
          aqlArray.push qb[condOp].apply null, conditionalPart.aqlArray
          merge true, boundVars, conditionalPart.boundVars

      # If the value is not an array, fall back to regular fields
      cond2push = switch
        # number comparison
        when condOp in ['lte', 'lt', 'gte', 'gt', 'eq', 'neq']
          qb[condOp] "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"

        # range comparison
        when condOp is 'between'
          [qb.gte("#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue[0])}"),  qb.lte("#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue[1])}")]

        # string comparison
        when condOp is 'like'
          qb.not qb.LIKE "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"
        when condOp is 'nlike'
          qb.LIKE "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"

        # array comparison
        when condOp is 'nin'
          qb.not qb.in "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"
        when condOp is 'in'
          qb.in "#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"

        # geo comparison (extra object)
        when 'near'
          # 'near' does not create a condition in the filter part, it returnes the lat/long pair
          # the query will be done from the querying method itself
          [lat, long] = condValue.split(',')
          collection = @getCollectionName model
          if filter.limit?
            geoExpr = qb.NEAR collection, lat, long, filter.limit
          else
            geoExpr = qb.NEAR collection, lat, long

        #  if we don't have a matching operator or no operator at all (condOp = false) then use the equivalence operator
        else
          qb.eq "(#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"

    return {
      aqlArray: aqlArray
      boundVars: boundVars
      geoExpr: geoExpr
    }



  ###
  ###
  _filter2fields: (model, filter, returnVariable) =>
    # variable to name the result
    returnVariable = returnVariable or 'result'
    includes = []
    excludes = []

    if Array.isArray filter.fields
      includes = filter.fields
    else
      _.each filter.fields, (field, key) -> if field then includes.push key else excludes.push key

    # KEEP only the specified fields to include if includes not empty
    return qb.fn('KEEP') returnVariable, includes if includes.length > 0

    # remove/UNSET the
    return qb.fn('UNSET') returnVariable, excludes if excludes.length > 0



  ###
  ###
  _filter2order: (model, filter, returnVariable) =>
    splitOrderClause = (order) ->
      [prop, dir] = order.split ' '
      dir = dir or 'ASC'
      return [prop, dir]

    if Array.isArray filter.order
      return _.chain(filter.order).map(splitOrderClause).flatten().value()
    else
      return splitOrderClause(filter.order)

  ###
  ###
  _filter2limit: (model, filter, returnVariable) =>
    if filter.skip?
      return qb.limit filter.skip, filter.limit
    else
      return qb.limit filter.limit

  ###
  ###
  # _filter2include: (model, filter, returnVariable) =>
  # TODO:
  # if (filter && filter.include) [
  #   self._models[model].model.include(objs, filter.include, callback);
  # ] else [
  #   callback(null, objs);
  # ]


  ###
  ###
  # TODO: create a function that can be called with the filter array only
  _filter2parts: (model, filter, returnVariable) =>
    # ================
    # = filter.where =
    # ================
    # TODO: where part is FILTER part of query
    # filter.where -> use buildWhere to create FILTER statement
    if not filter.where? or typeof filter.where isnt 'object'
      filterWhere = null
    else
      filterWhere = @_filter2where model, filter, resultVariable

    # =================
    # = filter.fields =
    # =================
    # TODO: fields part should be used in RETURN part of query
    # filter.fields -> use AQL-KEEP or AQL-UNSET to reduce final returned object
    if not filter.fields? or typeof filter.fields isnt 'object'
      filterFields = null
    else
      filterFields = @_filter2fields model, filter, returnVariable

    # ================
    # = filter.order =
    # ================
    # TODO: order part should be used in ORDER part of query
    # filter.order -> query-builder for sorting
    if not filter.order? or typeof filter.order not in ['object', 'string']
      filterOrder = null
    else
      filterOrder = @_filter2order model, filter, returnVariable

    # ==============================
    # = filter.limit & filter.skip =
    # ==============================
    # TODO: order part should be used in LIMIT part of query
    # filter.limit & filter.skip -> query-builder for limit & skip
    if not filter.limit?
      filterLimit = null
    else
      filterLimit = @_filter2limit model, filter, returnVariable

    # ==================
    # = filter.include =
    # ==================
    # TODO:
    # if (filter && filter.include) {
    #   self._models[model].model.include(objs, filter.include, callback);
    # } else {
    #   callback(null, objs);
    # }

    return {
      where: filterWhere
      fields: filterFields
      order: filterOrder
      limit: filterLimit
      # include: filterInclude
    }

  ###
  ###
  _filter2query: (model, filter) =>
    debug '_filter2query', model, filter if @debug


    collection = @getCollectionName model
    collVariable = collection.charAt 0
    returnVariable = 'result'

    boundVars = []

    parts = _filter2parts model, filter, returnVariable

    # define returnVariable
    aql = qb.for(returnVariable)

    # 1) check where-part if we have a geo expression that we must include in the in-clause, if not use in-collection
    coll = if parts.where.geoObject? then parts.where.geoObject else '@@collection'
    aql = aql.in(coll)

    # 2) use filter from where-part to filter, merge the boundVars from where into the global boundVars
    merge true, boundVars, parts.where.boundVars
    aql = aql.filter qb.and.apply null, parts.where.aqlArray

    # 3) use order to sort result on item level
    aql = aql.sort.apply null, part.order if parts.order?

    # 4) use limit to slice result on item level
    aql = aql.limit.apply null, part.limit if parts.limit?

    # 5) use field to return fields-filterd result on attribute level or plain object
    returnExpr = if parts.fields? then parts.fields else returnVariable
    aql = aql.return returnExpr

    return {
      aql: aql
      boundVars: boundVars
    }


  ###
    Find matching model instances by the filter

    @param [String] model The model name
    @param [Object] filter The filter
    @param [Function] callback Callback with (possible) error object or list of objects
  ###
  all: (model, filter, callback) =>
    all_aql = @_filter2query model, filter

    @query all_aql.aql, all_aql.boundVars, (err, result) ->
      callback err if err

      # filter include
      if filter.include?
        @getModelClass.model.include result, filter.include, callback
      else
        callback null, result



  ###
    Delete all instances for the given model

    @param [String] model The model name
    @param [Object] [where] The filter for where
    @param [Function] callback Callback with (possible) error object or the number of affected objects
  ###
  destroyAll: (model, where, callback) =>
    debug 'destroyAll', model, where if @debug

    collection = @getCollectionName(model)
    collVariable = collection.charAt 0

    bindVars = {
      collection: collection
      model: collVariable
    }

    # for .. in ..
    aql = qb.for('@model').in('@@collection')
    # filter ...
    if where
      whereFilter = @buildWhere model, where, modelVariable
      aql = aql.filter qb.and.apply null, whereFilter.aqlArray
      merge true, bindVars, whereFilter.bindVars

    # remove ...
    aql = aql.remove('@model').in('@@collection').returnOld('result')

    @query aql, bindVars, (err, result) ->
      callback err if err
      callback null, result.length

  ###
    Count the number of instances for the given model

    @param [String] model The model name
    @param [Function] callback Callback with (possible) error object or the number of affected objects
    @param [Object] where The filter for where
  ###
  count: (model, callback, where) =>
    debug 'count', model, where if @debug

    collection = @getCollectionName(model)
    collVariable = collection.charAt 0

    bindVars = {
      collection: collection
      model: collVariable
    }

    # for .. in ..
    aql = qb.for('@model').in('@@collection')
    # filter ...
    if where
      whereFilter = @buildWhere model, where, modelVariable
      aql = aql.filter qb.and.apply null, whereFilter.aqlArray
      merge true, bindVars, whereFilter.bindVars

    aql = aql.return '@model'

    @query aql, bindVars, (err, result) ->
      callback err if err
      callback null, result.length


  ###
    Update properties for the model instance data

    @param [String] model The model name
    @param [String] id The models id
    @param [Object] data The model data
    @param [Function] callback Callback with (possible) error object or the updated object
  ###
  updateAttributes: (model, id, data, cb) =>
    debug 'updateAttributes', model, id, data if @debug

    collection = @getCollectionName(model)
    collVariable = collection.charAt 0

    bindVars = {
      collection: collection
      id: id
    }

    # for .. in ..
    aql = qb.for('updateDoc').in('@@collection').filter('updateDoc._key','@id').update('updateDoc').with(data).in('@@collection').returnNew('result')

    @query aql, bindVars, (err, result) ->
      callback err if err
      callback null, result

  ###
    Update all matching instances

    @param [String] model The model name
    @param [Object] where The search criteria
    @param [Object] data The property/value pairs to be updated
    @param [Function] callback Callback with (possible) error object or the number of affected objects
  ###
  update: (model, where, data, cb) =>
    return @updateAll model, where, data, cb

  updateAll: (model, where, data, cb) =>
    debug 'updateAll', model, where, data if @debug

    # TODO: FOR & FILTER (from id) & UPDATE (with data)
    collection = @getCollectionName(model)
    collVariable = collection.charAt 0

    bindVars = {
      collection: collection
      model: collVariable
    }

    # for .. in ..
    aql = qb.for('@model').in('@@collection')
    # filter ...
    if where
      whereFilter = @buildWhere model, where, modelVariable
      aql = aql.filter qb.and.apply null, whereFilter.aqlArray
      merge true, bindVars, whereFilter.bindVars

    aql = aql.update(modelVariable).with(data).in('@@collection')

    @query aql, bindVars, (err, result) ->
      callback err if err
      callback null, result.length

  # @extend require('./MigrationMixin')
  # ===================
  # = Migration Mixin =
  # ===================
      ###
        Perform autoupdate for the given models. It basically calls ensureIndex

        @param [String[]] [models] A model name or an array of model names. If not present, apply to all models
        @param [Function] [cb] The callback function
      ###
      autoupdate: (models, cb) =>
        if @db
          debug 'autoupdate' if @debug

          if (not cb) and (typeof models is 'function')
            cb = models
            models = undefined

          # First argument is a model name
          models = [models] if typeof models is 'string'

          models = models or Object.keys @_models

          async.each( models, ((model, modelCallback) ->
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
                  options = { name: indexName }
                  index = {
                    keys: index
                    options: options
                  }

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
                  options = { background: true }
                  options.unique = true if property.unique


                indexList.push { keys: index, options: options }

            debug 'create indexes' if @debug
            async.each( indexList, ((index, indexCallback) ->
              debug 'ensureIndex' if @debug

              # TODO: ensureIndex for ArangoDB
              # self.collection(model).ensureIndex(index.fields || index.keys, index.options, indexCallback);
            ), modelCallback )
          ), cb)
        else
          @dataSource.once 'connected', () -> @autoupdate models, cb



      ###
        Perform automigrate for the given models. It drops the corresponding collections and calls ensureIndex

        @param [String[]] [models] A model name or an array of model names. If not present, apply to all models
        @param [Function] [cb] The callback function
      ###
      automigrate: (models, cb) =>
        if @db
          debug 'automigrate' if @debug

          if (not cb) and (typeof models is 'function')
            cb = models
            models = undefined

          # First argument is a model name
          models = [models] if typeof models is 'string'

          async.each(models, ((model, modelCallback) ->
            debug "drop collection: #{model}"
            @db.dropCollection model, (err, collection) ->
              if err
                #  For errors other than 'ns not found' (collection doesn't exist)
                return modelcallback err if not (err.name is 'MongoError' and err.ok is 0 and err.errmsg is 'ns not found')

              # Recreate the collection
              debug "create collection: #{model}"

              @db.createCollection model, modelcallback

          ), ((err) ->
            return cb and cb err if err
            @autoupdate models, cb
          ))
        else
          @dataSource.once 'connected', () -> @automigrate models cb


exports.ArangoDBConnector = ArangoDBConnector
