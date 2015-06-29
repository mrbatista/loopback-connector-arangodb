###
  Module dependencies
###
url = require 'url'

# ArangoDB Query Builder
qb = require 'aqb'

debug = require('debug') 'loopback:connector:arango'
merge = require 'extend'
_ = require 'underscore'

Connector = require('loopback-connector').Connector;


###
  Initialize the ArangoDB connector for the given data source
  
  @param dataSource [DataSource] The data source instance
  @param callback [Function] The callback function
###
exports.initialize = (dataSource, callback) ->
  console.log 'initialize'
  dataSource.connector = new ArangoDBConnector datasource
  datasource.connector.connect callback if callback?
  console.log 'dataSource'


###
  Loopback Arango Connector
  
  @author Navid Nikpour
###
class ArangoDBConnector
  @extend: (obj) ->
    for key, value of obj when key not in ['extended', 'included']
      @[key] = value

    obj.extended?.apply(@)
    this

  @include: (obj) ->
    for key, value of obj when key not in ['extended', 'included']
      # Assign properties to the prototype
      @::[key] = value

    obj.included?.apply(@)
    this
  
  @optimizeSettings: (settings) ->
    # settings is a string, dsn coded e.g. http://localhost:8529/ConnectorTest
    if typeof settings is 'string'
      url_obj = url.parse settings
    
      
      database = url_obj.pathname[1..].split('/')[0]
      delete url_obj.path
      delete url_obj.pathname
      url_obj.protocol = 'http:'
      url_obj.slashes = true
    
      url = url.format url_obj
      databaseName = database
    else
      user = settings.user or settings.username or null
      pass = settings.pass or settings.password or null
      auth = if user and pass then "#{user}:#{pass}" else null
    
      host = settings.host or 'localhost'
      port = settings.port or 8529
      hostname = "#{host}:#{port}"
    
      url = if auth? then "http://#{auth}@#{hostname}" else "http://#{hostname}"
      database = settings.database or settings.db or '_system'
      
    
    return {
      url: url
      databaseName: database
      promise: false
    }
  
  
  
  
  ###
    The constructor for ArangoDB connector

    @param dataSource [Object] Object to connect this connector to a data source
    @option settings host [String] The host/ip address to connect with
    @option settings port [Number] The port to connect with
    @option settings database/db [String] The database to connect with
    @option settings headers [Object] Object with header to include in every request
  
    @param dataSource [DataSource] The data source instance
  ###
  constructor: (dataSource) ->
    console.log 'constructor'
    Connector.call this, 'arangodb', dataSource.settings
    @dataSource = dataSource
    @dataSource.connector = this
    
    settings = dataSource.settings or {}
    @settings = settings
    
    @name = 'arangodb'
    @_models = {}
    
    @arangoConfig = connectionConfig @settings
    @qb = require('aqb')
    
    return this
  
  
  # one file per functionality
  @extend require('./core')
  @extend require('./crud')
  @extend require('./migration')

require('util').inherits ArangoDBConnector, Connector

exports.ArangoDBConnector = ArangoDBConnector