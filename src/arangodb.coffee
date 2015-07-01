###
  Module dependencies
###
url = require 'url'

# ArangoDB Query Builder
ajs = require 'arangojs'
qb = require 'aqb'

debug = require('debug') 'loopback:connector:arango'
merge = require 'extend'
_ = require 'underscore'

Connector = require('loopback-connector').Connector;


exports.generateArangoDBObject = generateArangoDBObject = (settings) ->
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


###
  Initialize the ArangoDB connector for the given data source
  
  @param dataSource [DataSource] The data source instance
  @param callback [Function] The callback function
###
exports.initialize = (dataSource, callback) ->
  return if not ajs?
  dataSource.driver = ajs;
  
  settings = generateArangoDBObject dataSource.settings
  
  dataSource.connector = new ArangoDBConnector settings, dataSource
  # dataSource.connector.connect callback if callback?


###
  Loopback Arango Connector
  
  @author Navid Nikpour
###
class ArangoDBConnector extends Connector
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
    console.log 'constructor called'
    super 'arangodb', settings
    
    # link to datasource
    @dataSource = dataSource
    
    # debug
    @debug = dataSource.settings.debug or debug.enabled
    
    # Query builder
    @qb = require('aqb')
    
    @db = require('arangojs') @settings
    @api = @db.route '_api'
  
  # one file per functionality
  @extend require('./CoreMixin')
  @extend require('./CrudMixin')
  @extend require('./MigrationMixin')

# require('util').inherits ArangoDBConnector, Connector

exports.ArangoDBConnector = ArangoDBConnector