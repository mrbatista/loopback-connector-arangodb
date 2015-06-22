###
  Module dependencies
###
util = require 'util'
url = require 'url'

ArangoConnection = require 'arangojs'
qb = require 'aqb'
async = require 'async'
Connector = require('loopback-connector').Connector
debug = require('debug') 'loopback:connector:arango'
extend = require 'extend'
_ = require 'underscore'

###
  create as connection object for arangodb from loopback connector options
  @private
  
  @param [Object] options The options for initializing the connector
  @option options host [String] The host/ip address to connect with
  @option options port [Number] The port to connect with
  @option options database/db [String] The database to connect with
  @option options headers [Object] Object with header to include in every request
  
  @returns [Object] The connection object
###
generateArangoConnectionObject = (options) ->
  retOptions =
    host: options.host or options.hostname or '127.0.0.1'
    port: options.port or '8529'
    database: options.database or options.db or '_system'
    headers: options.headers or []
  
  return retOptions
  # TODO: how to authenticate: Basic HTTP authentication
  # var username = options.username or options.user;
  # if (username && options.password) [
  #   return "mongodb://" + username + ":" + options.password + "@" + options.hostname + ":" + options.port + "/" + options.database;
  # ] else [
  #   return "mongodb://" + options.hostname + ":" + options.port + "/" + options.database;
  # ]


###
  Initialize the MongoDB connector for the given data source
  
  @param dataSource [DataSource] The data source instance
  @param callback [Function] The callback function
###
exports.initialize = (dataSource, callback) ->
  return if not ArangoDB?
  
  # TODO: convert settings into the clients options object
  s = dataSource.settings
  
  dataSource.connector = new ArangoDB s, dataSource
  
  ###
    Connector instance can have an optional property named as DataAccessObject that provides
    static and prototype methods to be mixed into the model constructor. The property can be defined
    on the prototype.
  ###
  dataSource.connector.DataAccessObject = () -> # dummy function
  
  ###
    Connector instance can have an optional function to be called to handle data model definitions.
    The function can be defined on the prototype too.
    @param model The name of the model
    @param properties An object for property definitions keyed by propery names
    @param settings An object for the model settings
  ###
  # connector.define : (model, properties, settings) [
  #   #  ...
  # ];
  
  # connector.connect( , postInit); # Run some async code for initialization
  # process.nextTick(postInit);
  return dataSource.connector.connect(callback)
  
  


###
  Loopback Arango AQL Connector
  Inherited from the SQL Connector
  
  @author Navid Nikpour
###
class ArangoDB extends SQLConnector
