# This test written in mocha+should.js
should = require('./init');

DataSource = require('loopback-datasource-juggler').DataSource;
ArangoDBConnector = require('..').ArangoDBConnector

describe 'arangodb core functionality', () ->
  
  describe 'connecting', () ->
    describe 'connection generator', () ->
      
      it 'should create an object when using a string, formatted like a dsn', (done) ->
        dsn_config = "arangodb://connector:connector@192.168.99.100:32768/ConnectorTest"
        config = ArangoDBConnector.optimizeSettings dsn_config
        
        expected_config = { url: 'http://connector:connector@192.168.99.100:32768', databaseName: 'ConnectorTest', promise: false }
        
        config.should.eql expected_config
        done()
      
      it 'should create an object when using a object, formatted like loopback connection settings', (done) ->
        loopback_config = {
          connector: 'arangodb',
          host: '192.168.99.100'
          port: 32768
          username: 'connector'
          password: 'connector'
          database: 'ConnectorTest'
        }
        config = ArangoDBConnector.optimizeSettings loopback_config
        
        expected_config = { url: 'http://connector:connector@192.168.99.100:32768', databaseName: 'ConnectorTest', promise: false }
        
        config.should.eql expected_config
        done()
    
    
    
    
    describe 'authentication', () ->
      it "should throw an error when using wrong credentials", (done) ->
        dsn_config = "arangodb://connector:connector@192.168.99.100:32768/ConnectorTest"
        db = getDataSource dsn_config
        console.log db
        done()
    
      it "should connect to the database when using right credentials", (done) ->
        done()
        # dsn_config = "arangodb://connector:connector@192.168.99.100:32768/ConnectorTest"
        # db = getDataSource dsn_config
        # done()
    
    describe 'exposed properties', () ->
      it "should expose a property 'db' to access the driver directly", (done) ->
        done()
    
      it "should expose a property 'qb' to access the query builder directly", (done) ->
        done()
    
      it "should expoase a property 'version' to retrieve the version of Database", (done) ->
        done()
    
    describe 'conversion', () ->
      it "should convert Loopback Data Types to the respective ArangoDB Data Types", (done) ->
        done()
      
      it "should convert ArangoDB Types to the respective Loopback Data Types", (done) ->
        done()
    
    describe 'connector access', () ->
      it "should get the collection name from the name of the model", (done) ->
        done()
    
      it "should get the collection name from the 'name' property on the 'arangodb' property", (done) ->
        done()
    
    describe 'querying', () ->
      it "should execute a custom AQL query provided as a string", (done) ->
        done()
    
      it "should execute a custom AQL query provided using the query builder object", (done) ->
        done()
    
    describe 'transaction', () ->
      it "should execute a transaction with the action provided as a string", (done) ->
        done()
    
      it "should execute a transaction with the action provided as a function", (done) ->
        done()
    
      it "should execute a transaction with the action provided as a function, including parameters", (done) ->
        done()
    
    