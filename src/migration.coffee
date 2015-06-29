module.exports = {
  extended: ->
    @include {
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
    }
}