module.exports = {
  extended: ->
    @include {
      ###
        Connect to ArangoDB
  
        @param callback [Function] The callback function, called the with created connection
      ###
      connect: (callback) =>
        console.log 'connect called'
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
        if @getModelClass().settings.arangodb
          model = getModelClass().settings.arangodb?.collection or model
        
        return model
      
      
      ###
        Converts the retrieved data from the database to JSON, based on the properties of a given model
    
        @param model [String] The model name to look up the properties
        @param data [Object] The data from DB

        @return [Object] The converted data as an JSON Object
      ###
      fromDatabase: (model, data) =>
        return null if not data?
    
        properties = @getModelClass().properties
    
        for key, val of data
          # change _key value to an id property and then delete _id (database wide doc handle) and _key (collection wide doc handle)
          if key in ['_key', '_id']
            data.id = switch
              when key is '_key' then val
              when key is '_id' then val.split('/')[0]
            delete data[key]
            continue
      
          # Buffer
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
            # from Array with two elements
            if Array.isArray data[key]
              [latitude, longitude] = val
            else
              [latitude, longitude] = val if val.latitude? and val.longitude?
              [lat, lng] = val if val.lat? and val.lng?
              latitude = lat
              longitude = lng
        
            data[key] =
              lat: latitude
              lng: longitude
      
          # TODO: still to come: Boolean, Number, Array and any arbitrary type
    
        return data
  
  
  
      ###
        Converts JSON to insert into the database, based on the properties of a given model
  
        @param model [String] The model name to look up the properties
        @param data [Object] The JSON object to transferred to the database
  
        @return [Object] The converted data as an Plain Javascript Object 
      ###
      toDatabase: (model, data) =>
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
        @param callback [Function] The callback function, called with a (possible) error object and the query's result
      ###
      query: (query, bindVars, callback) =>
        debug 'query', query, bindVars if @debug
    
        @db.query query, bindVars, (err, cursor) ->
          callback err if err
          cursor.all (err, result) ->
            callback err if err
            callback null, result
      
      ###
        Checks the version of the ArangoDB
        
        @param callback [Function] The calback function, called with a (possible) error object and the server versio
      ###
      version: (callback) =>
        debug 'version' if @debug
        
        if @version?
          callback null, @version
        else
          @api 'version', (err, result) ->
            callback err if err
            @version = result
            callback null, @version
        
    }
}