module.exports = {
  extended: ->
    @include {
      ###
        Create a new model instance for the given data
  
        @param model [String] The model name
        @param data [Object] The data to create
        @param callback [Function] The callback function, called with a (possible) error object and the created object's id
      ###
      create: (model, data, callback) =>
        debug 'create', model, data if @debug
    
        aql = qb.insert('@data').in('@@collection').returnNew('inserted')
        bindVars = [
          data: data,
          collection: @getCollection(model)
        ]
    
        @query aql, bindVars, (err, result) ->
          callback err if err
          callback null, result[0]._key if result.length > 0
          callback null, result
  
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
    
    
        @transaction @getCollection(model), action, [ id: id, data: data, collection: @getCollection(model) ], (err, result) ->
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
        bindVars = [
          collection: @getCollection(model),
          id: id
        ]
    
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
        bindVars = [
          collection: @getCollection(model)
          id: id
        ]
    
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
              collection = @getCollection model
              if filter.limit?
                geoExpr = qb.NEAR collection, lat, long, filter.limit
              else
                geoExpr = qb.NEAR collection, lat, long
        
            #  if we don't have a matching operator or no operator at all (condOp = false) then use the equivalence operator
            else
              qb.eq "(#{returnVariable}.#{condProp}", "#{assignNewQueryVariable(condValue)}"
      
        return [
          aqlArray: aqlArray
          boundVars: boundVars
          geoExpr: geoExpr
        ]
    
  
  
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
        
    
        collection = @getCollection model
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
    
        return [
          aql: aql
          boundVars: boundVars
        ]
    
  
      ###
        Find matching model instances by the filter
    
        @param [String] model The model name
        @param [Object] filter The filter
        @param [Function] [callback] Callback with (possible) error object and list of objects
      ###
      all: (model, filter, callback) =>
        all_aql = @filter2query model, filter
    
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
        @param [Function] [callback] Callback with (possible) error object and the number of affected objects 
      ###
      destroyAll: (model, where, callback) =>
        debug 'destroyAll', model, where if @debug
    
        collection = @getCollection(model)
        collVariable = collection.charAt 0
    
        bindVars = [
          collection: collection
          model: collVariable
        ]
    
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
        @param [Function] [callback] The callback function
        @param [Function] [callback] Callback with (possible) error object and the number of affected objects
      ###
      count: (model, callback, where) =>
        debug 'count', model, where if @debug
    
        collection = @getCollection(model)
        collVariable = collection.charAt 0
    
        bindVars = [
          collection: collection
          model: collVariable
        ]
    
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
        @param [Function] [callback] Callback with (possible) error object and the updated object
      ###
      updateAttributes: (model, id, data, cb) =>
        debug 'updateAttributes', model, id, data if @debug
    
        collection = @getCollection(model)
        collVariable = collection.charAt 0
    
        bindVars = [
          collection: collection
          id: id
        ]
    
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
        @param [Function] [callback] Callback with (possible) error object and the number of affected objects
      ###
      update: (model, where, data, cb) =>
        return @updateAll model, where, data, cb
  
      updateAll: (model, where, data, cb) =>
        debug 'updateAll', model, where, data if @debug
    
        # TODO: FOR & FILTER (from id) & UPDATE (with data)
        collection = @getCollection(model)
        collVariable = collection.charAt 0
    
        bindVars = [
          collection: collection
          model: collVariable
        ]
    
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
    }
}  
