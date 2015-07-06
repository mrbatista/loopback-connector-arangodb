# This test written in mocha+should.js
should = require('./init');

DataSource = require('loopback-datasource-juggler').DataSource
GeoPoint = require('loopback-datasource-juggler').GeoPoint
arangodb = require '..'
ArangoDBConnector = arangodb.ArangoDBConnector
QB = require 'aqb'
ajs = require 'arangojs'

describe 'arangodb core functionality:', () ->
  ds = null
  wrong_auth = null
  before () ->
    # TODO: create the test settings from reading in .loopbackrc
    ds = getDataSource { url: 'http://connector:connector@192.168.99.100:32769/ConnectorTest' }
  
  describe 'connecting:', () ->
    before () ->
      # TODO: create the test settings from reading in .loopbackrc and modify it
      wrong_auth = getDataSource { url: 'http://connector:wrong@192.168.99.100:32768/ConnectorTest' }
      generateConnObject = arangodb.generateConnObject
      
      simple_model = ds.define 'SimpleModel', {
        name:
          type: String
      } 
    
      complex_model = ds.define 'ComplexModel', {
        name:
          type: String
        money:
          type: Number
        birthday:
          type: Date
        icon:
          type: Buffer
        active:
          type: Boolean
        likes:
          type: Array
        address:
          street:
            type: String
          house_number:
            type: String
          city:
            type: String
          zip:
            type: String
          country:
            type: String
        location:
          type: GeoPoint
      }, {
        options:
          arangodb:
            collection: 'Complex'
      }
    
    describe 'connection generator:', () ->
      it 'should create the default connection object when called with an empty settings object', (done) ->
        settings = {}
        expectedConnObj = {
          url: 'http://127.0.0.1:8529'
          databaseName: 'loopback_db'
          promise: false
        }
        
        connObj = arangodb.generateConnObject settings
        connObj.should.eql expectedConnObj
        done()
      
      it 'should create an connection using only the "url" property, ignoring other connection settings', (done) ->
        # TODO: create the test settings from reading in .loopbackrc and modify it
        settings = {
          url: 'http://connector:connector@192.168.99.100:32768/ConnectorTest'
          hostname: 'http://localhost'
          port: 1234
          dataBase: 'NotExistent'
          username: 'wrongUser'
          password: 'wrongPassword'
        }
        expectedConnObj = {
          url: 'http://connector:connector@192.168.99.100:32768'
          databaseName: 'ConnectorTest'
          promise: false
        }
        
        connObj = arangodb.generateConnObject settings
        connObj.should.eql expectedConnObj
        done()
            
      it 'should create an connection using only the "url" property, considers other non-connection settings', (done) ->
        # TODO: create the test settings from reading in .loopbackrc and modify it
        settings = {
          url: 'http://connector:connector@192.168.99.100:32768/ConnectorTest'
          promise: true
        }
        expectedConnObj = {
          url: 'http://connector:connector@192.168.99.100:32768'
          databaseName: 'ConnectorTest'
          promise: true
        }
        
        connObj = arangodb.generateConnObject settings
        connObj.should.eql expectedConnObj
        done()
      
      it 'should create an connection using the connection settings when url is not set', (done) ->
        # TODO: create the test settings from reading in .loopbackrc and modify it
        settings = {
          host: '192.168.99.100'
          port: 32768
          database: 'ConnectorTest'
          username: 'connector'
          password: 'connector'
          promise: true
        }
        expectedConnObj = {
          url: 'http://connector:connector@192.168.99.100:32768'
          databaseName: 'ConnectorTest'
          promise: true
        }
        
        connObj = arangodb.generateConnObject settings
        connObj.should.eql expectedConnObj
        done()
    
    
    # describe 'authentication:', () ->
    #   it "should throw an error when using wrong credentials", (done) ->
    #     dsn_config = "arangodb://connector:connector@192.168.99.100:32768/ConnectorTest"
    #     db = getDataSource dsn_config
    #     console.log db
    #     done()
    #
    #   it "should connect to the database when using right credentials", (done) ->
    #     done()
    #     # dsn_config = "arangodb://connector:connector@192.168.99.100:32768/ConnectorTest"
    #     # db = getDataSource dsn_config
    #     # done()
    
  
  describe 'exposed properties:', () ->
    it 'should expose a property "db" to access the driver directly', (done) ->
      ds.connector.db.should.be.not.null
      ds.connector.db.should.be.ajs
      done()
  
    it 'should expose a property "qb" to access the query builder directly', (done) ->
      ds.connector.qb.should.not.be.null
      ds.connector.qb.should.be.QB
      done()
    
    it 'should expose a property "api" to access the HTTP API directly', (done) ->
      ds.connector.api.should.not.be.null
      ds.connector.api.should.be.Object
      done()
      
    it 'should expose a function "version" which callsback with the version of the database', (done) ->
      ds.connector.getVersion (err, result) ->
        done err if err

        result.should.exist
        result.should.have.keys ['server', 'version']
        result.version.should.match /[0-9]+\.[0-9]+\.[0-9]+/
        done()
  
  
  describe 'connector details:', () ->
    it 'should provide a function "getTypes" which returns the array ["db", "nosql", "arangodb"]', (done) ->
      types = ds.connector.getTypes()
      
      types.should.not.be.null
      types.should.be.Array
      types.length.should.be.above(2)
      types.should.eql ['db','nosql','arangodb']
      done()
    
    it 'should provide a function "getDefaultIdType" that returns String', (done) ->
      defaultIdType = ds.connector.getDefaultIdType()
      
      defaultIdType.should.not.be.null
      defaultIdType.should.be.a.class
      done()
  
  describe 'conversion', () ->
    it "should convert Loopback Data Types to the respective ArangoDB Data Types", (done) ->
      toDB = {
        name:
          first: 'Navid'
          last: 'Nikpour'
        profession: 'IT Consultant'
        money: 3000
        birthday: new Date('12.09.1980')
        icon: new Buffer('a20')
        active: true
        likes: ['skiing', 'tennis']
        location: new GeoPoint { lat: 49.0014277, lng: 8.4070679 }
      }
      
      dbData = ds.connector.toDatabase 'ComplexModel', toDB
      expected = {
        name:
          first: 'Navid'
          last: 'Nikpour'
        profession: 'IT Consultant'
        money: 3000
        birthday: new Date('12.09.1980')
        icon: new Buffer('a20').toString('base64')
        active: true
        likes: ['skiing', 'tennis']
        location: 
          lat: 49.0014277
          lng: 8.4070679
      }
      dbData.should.eql expected
      done()
      
    
    it "should convert ArangoDB Types to the respective Loopback Data Types", (done) ->
      fromDB = {
        name:
          first: 'Navid'
          last: 'Nikpour'
        profession: 'IT Consultant'
        money: 3000
        birthday: new Date('12.09.1980')
        icon: new Buffer('a20').toString('base64')
        active: true
        likes: ['skiing', 'tennis']
        location: 
          lat: 49.0014277
          lng: 8.4070679
      }
      jsonData = ds.connector.fromDatabase 'ComplexModel', fromDB
      expected = {
        name:
          first: 'Navid'
          last: 'Nikpour'
        profession: 'IT Consultant'
        money: 3000
        birthday: new Date('12.09.1980')
        icon: new Buffer('a20')
        active: true
        likes: ['skiing', 'tennis']
        location: new GeoPoint { lat: 49.0014277, lng: 8.4070679 }
      }
      
      jsonData.should.eql expected
      done()
  
  describe 'connector access', () ->
    it "should get the collection name from the name of the model", (done) ->
      simpleCollection = ds.connector.getCollectionName 'SimpleModel'
      
      simpleCollection.should.not.be.null
      simpleCollection.should.be.a.String
      simpleCollection.should.eql 'SimpleModel'
      
      done()

    it "should get the collection name from the 'name' property on the 'arangodb' property", (done) ->
      complexCollection = ds.connector.getCollectionName 'ComplexModel'
      
      complexCollection.should.not.be.null
      complexCollection.should.be.a.String
      complexCollection.should.eql 'Complex'
      
      done()
  
  describe 'querying', () ->
    it "should execute a AQL query with no variables provided as a string", (done) ->
      aql_query_string = [
        "/* Returns the sequence of integers between 2010 and 2013 (including) */",
        "FOR year IN 2010..2013",
        " RETURN year"
      ].join("\n")
      
      ds.connector.query aql_query_string, (err, cursor) ->
        done err if err
        cursor.should.exist
        cursor.all (err, values) ->
          done err if err
          
          values.should.not.be.null
          values.should.be.a.Array
          values.should.eql [ 2010, 2011, 2012, 2013 ]
          done()
    
    it "should execute a AQL query with bound variables provided as a string", (done) ->
      aql_query_string = [
        "/* Returns the sequence of integers between 2010 and 2013 (including) */",
        "FOR year IN 2010..2013",
        "  LET following_year = year + @difference",
        "  RETURN { year: year, following: following_year }"
      ].join("\n")
      
      ds.connector.query aql_query_string, { difference: 1 }, (err, cursor) ->
        done err if err
        cursor.should.exist
        cursor.all (err, values) ->
          done err if err
          
          values.should.not.be.null
          values.should.be.a.Array
          values.should.eql [ {year: 2010, following: 2011 }, { year: 2011, following: 2012 }, { year: 2012, following: 2013 }, { year: 2013, following: 2014 } ]
          done()
  
    it "should execute a AQL query with no variables provided using the query builder object", (done) ->
      aql_query_object = ds.connector.qb.for('year').in('2010..2013').return('year')

      ds.connector.query aql_query_object, (err, cursor) ->
        done err if err
        cursor.should.exist
        cursor.all (err, values) ->
          done err if err

          values.should.not.be.null
          values.should.be.a.Array
          values.should.eql [ 2010, 2011, 2012, 2013 ]
          done()

    it "should execute a AQL query with bound variables provided using the query builder object", (done) ->
      qb = ds.connector.qb
      
      aql = qb.for('year').in('2010..2013')
      aql = aql.let 'following', qb.add(qb.ref('year'), qb.ref('@difference'))
      aql = aql.return {
        year: qb.ref('year'),
        following: qb.ref('following')
      }
      
      
      ds.connector.query aql, { difference: 1 }, (err, cursor) ->
        done err if err
        cursor.should.exist
        cursor.all (err, values) ->
          done err if err
          
          values.should.not.be.null
          values.should.be.a.Array
          values.should.eql [ {year: 2010, following: 2011 }, { year: 2011, following: 2012 }, { year: 2012, following: 2013 }, { year: 2013, following: 2014 } ]
          done()
  
  # TODO: find a way to test transactions
  # describe 'transaction', () ->
  #   it "should execute a transaction with the action provided as a string", (done) ->
  #     done false
  #
  #   it "should execute a transaction with the action provided as a function", (done) ->
  #     done false
  #
  #   it "should execute a transaction with the action provided as a function, including parameters", (done) ->
  #     done false
    
    