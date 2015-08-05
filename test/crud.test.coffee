# This test written in mocha+should.js
should = require('./init');

#DataSource = require('loopback-datasource-juggler').DataSource
#GeoPoint = require('loopback-datasource-juggler').GeoPoint
#QB = require 'aqb'
#ajs = require 'arangojs'
#chance = require('chance').Chance()
#
#arangodb = require '..'
#ArangoDBConnector = arangodb.ArangoDBConnector

describe 'arangodb crud functionality:', () ->
  db = null
  User = null
  Post = null
  Product = null
  PostWithObjectId = null
  PostWithNumberUnderscoreId = null

  before () ->
    db = getDataSource()

    User = db.define('User', {
      name: {type: String, index: true},
      email: {type: String, index: true, unique: true},
      age: Number,
      icon: Buffer
    }, {
      indexes: {
        name_age_index: {
          keys: {name: 1, age: -1}
        }, # The value contains keys and optinally options
        age_index: {age: -1} # The value itself is for keys
      }
    });

    Superhero = db.define('Superhero', {
      name: {type: String, index: true},
      power: {type: String, index: true, unique: true},
      address: {type: String, required: false, index: {mongodb: {unique: false, sparse: true}}},
      description: {type: String, required: false},
      geometry: {type: Object, required: false, index: {mongodb: {kind: "2dsphere"}}},
      age: Number,
      icon: Buffer
    }, {
      arangodb: {
        collection: 'sh'
      }
    });

    Post = db.define('Post', {
      title: {type: String, length: 255, index: true},
      content: {type: String},
      comments: [String]
    }, {
      arangodb: {
        collection: 'PostCollection' #Customize the collection name
      }
    });

    Product = db.define('Product', {
      name: {type: String, length: 255, index: true},
      description: {type: String},
      price: {type: Number},
      pricehistory: {type: Object}
    }, {
      arangodb: {
        collection: 'ProductCollection' #Customize the collection name
      }
    });

    User.hasMany(Post);
    Post.belongsTo(User);


  it 'should have created simple User models', (done) ->

    User.create {age: 3, content: 'test'}, (err, user) ->
      done err if err
      user.age.should.be.equal(3)
      user.content.should.be.equal('test')
      user.id.should.not.be.null
      done()

  it 'should support Buffer type', (done) ->

    User.create {name: 'John', icon: new Buffer('1a2')}, (e, u)  ->
      User.findById u.id, (e, user) ->
        done e if e
        user.icon.should.be.an.instanceOf(Buffer)
        done()

#  it 'hasMany should support additional conditions', (done) ->
#
#    User.create {}, (e, u) ->
#      u.posts.create (e, p) ->
#        u.posts {where: {id: p.id}}, (err, posts) ->
#          should.not.exist(err)
#          posts.should.have.lengthOf(1)
#          done()
