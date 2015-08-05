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

    PostWithStringId = db.define('PostWithStringId', {
      id: {type: String, id: true},
      title: { type: String, length: 255, index: true },
      content: { type: String }
    });

    PostWithNumberUnderscoreId = db.define('PostWithNumberUnderscoreId', {
      _id: {type: Number, id: true},
      title: { type: String, length: 255, index: true },
      content: { type: String }
    });

    PostWithNumberId = db.define('PostWithNumberId', {
      id: {type: Number, id: true},
      title: { type: String, length: 255, index: true },
      content: { type: String }
    });

    User.hasMany(Post);
    Post.belongsTo(User);

    beforeEach (done) ->
      User.settings.arangodb = {};
      User.destroyAll ->
        Post.destroyAll ->
          PostWithNumberId.destroyAll ->
            PostWithNumberUnderscoreId.destroyAll ->
              PostWithStringId.destroyAll ->

              done()

  it 'should handle correctly type Number for id field _id', (done) ->

    PostWithNumberUnderscoreId.create {_id: 3, content: "test"}, (err, person) ->
      should.not.exist(err)
      person._id.should.be.equal(3)
    PostWithNumberUnderscoreId.findById person._id, (err, p) ->
      should.not.exist(err);
      p.content.should.be.equal('test');

      done()

  it 'should handle correctly type Number for id field _id using string', (done) ->

    PostWithNumberUnderscoreId.create {_id: 4, content: 'test'}, (err, person) ->
      should.not.exist(err);
      person._id.should.be.equal(4);
    PostWithNumberUnderscoreId.findById '4', (err, p) ->
      should.not.exist(err);
      p.content.should.be.equal('test');

      done()

#  it 'should allow to find post by id string if `_id` is defined id', (done) ->
#
#    PostWithObjectId.create (err, post) ->
#      PostWithObjectId.find {where: {_id: post._id.toString()}}, (err, p) ->
#      should.not.exist(err)
#      post = p[0]
#      should.exist(post)
#      post._id.should.be.an.instanceOf(db.ObjectID);
#
#      done()

#  it 'find with `_id` as defined id should return an object with _id instanceof ObjectID', (done) ->
#
#    PostWithObjectId.create (err, post) ->
#      PostWithObjectId.findById post._id, (err, post) ->
#        should.not.exist(err)
#        post._id.should.be.an.instanceOf(db.ObjectID)
#
#        done()

#  it 'should update the instance with `_id` as defined id', (done) ->
#
#    PostWithObjectId.create {title: 'a', content: 'AAA'}, (err, post) ->
#      post.title = 'b'
#      PostWithObjectId.updateOrCreate post, (err, p) ->
#        should.not.exist(err)
#        p._id.should.be.equal(post._id)
#      PostWithObjectId.findById post._id, (err, p) ->
#        should.not.exist(err)
#        p._id.should.be.eql(post._id)
#        p.content.should.be.equal(post.content)
#        p.title.should.be.equal('b')
#      PostWithObjectId.find {where: {title: 'b'}}, (err, posts) ->
#        should.not.exist(err)
#        p = posts[0]
#        p._id.should.be.eql(post._id)
#        p.content.should.be.equal(post.content)
#        p.title.should.be.equal('b')
#        posts.should.have.lengthOf(1)
#
#        done()

#  it('all should return object (with `_id` as defined id) with an _id instanceof ObjectID', function (done) ->
#
#    post = new PostWithObjectId({title: 'a', content: 'AAA'})
#    post.save (err, post) ->
#      PostWithObjectId.all {where: {title: 'a'}}, (err, posts) ->
#        should.not.exist(err)
#        posts.should.have.lengthOf(1)
#        post = posts[0]
#        post.should.have.property('title', 'a')
#        post.should.have.property('content', 'AAA')
#        post._id.should.be.an.instanceOf(db.ObjectID)
#
#        done()

  it 'all return should honor filter.fields, with `_id` as defined id', (done) ->

    post = new PostWithObjectId {title: 'a', content: 'AAA'}
    post.save (err, post) ->
      PostWithObjectId.all {fields: ['title'], where: {title: 'a'}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.lengthOf(1)
        post = posts[0]
        post.should.have.property('title', 'a')
        post.should.have.property('content', undefined)
        should.not.exist(post._id)

        done()

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

  it 'hasMany should support additional conditions', (done) ->

    User.create {}, (e, u) ->
      u.posts.create (e, p) ->
        u.posts {where: {id: p.id}}, (err, posts) ->
          should.not.exist(err)
          posts.should.have.lengthOf(1)

          done()

  it 'create should return id field but not arangodb _key', (done) ->

    Post.create {title: 'Post1', content: 'Post content'}, (err, post) ->
      should.not.exist(err)
      should.exist(post.id)
      should.not.exist(post._key)
      should.not.exist(post._id)

      done()

  it 'should allow to find by id string', (done) ->

    Post.create {title: 'Post1', content: 'Post content'}, (err, post) ->
      Post.findById post.id.toString(), (err, p) ->
        should.not.exist(err)
        should.exist(p)

        done()

  it 'should allow custom collection name', (done) ->

    Post.create {title: 'Post1', content: 'Post content'}, (err, post) ->
      Post.dataSource.connector.db.collection('PostCollection').findOne {id: post.id}, (err, p) ->
        should.not.exist(err)
        should.exist(p)

        done()

  it 'should allow to find by id using where', (done) ->

    Post.create {title: 'Post1', content: 'Post1 content'}, (err, p1) ->
      Post.create {title: 'Post2', content: 'Post2 content'}, (err, p2) ->
        Post.find {where: {id: p1.id}}, (err, p) ->
          should.not.exist(err)
          should.exist(p && p[0])
          p.length.should.be.equal(1)
          #Not strict equal
          p[0].id.should.be.eql(p1.id)

          done()

  it 'should allow to find by id using where inq', (done) ->

    Post.create {title: 'Post1', content: 'Post1 content'}, (err, p1) ->
      Post.create {title: 'Post2', content: 'Post2 content'}, (err, p2) ->
        Post.find {where: {id: {inq: [p1.id]}}}, (err, p) ->
          should.not.exist(err)
          should.exist(p && p[0])
          p.length.should.be.equal(1)
          #Not strict equal
          p[0].id.should.be.eql(p1.id)

          done()

  it 'should invoke hooks', (done) ->

    events = [];
    connector = Post.getDataSource().connector;
    connector.observe 'before execute', (ctx, next) ->
      ctx.req.command.should.be.string;
      ctx.req.params.should.be.array;
      events.push 'before execute ' + ctx.req.command
      next()

    connector.observe 'after execute', (ctx, next) ->
      ctx.res.should.be.object
      events.push 'after execute ' + ctx.req.command
      next()

    Post.create {title: 'Post1', content: 'Post1 content'}, (err, p1) ->
      Post.find (err, results) ->
        events.should.eql(['before execute insert', 'after execute insert',
          'before execute find', 'after execute find'])
        connector.clearObservers 'before execute'
        connector.clearObservers 'after execute'

        done(err, results)

  it 'should allow to find by number id using where', (done) ->
    PostWithNumberId.create {id: 1, title: 'Post1', content: 'Post1 content'}, (err, p1) ->
      PostWithNumberId.create {id: 2, title: 'Post2', content: 'Post2 content'}, (err, p2) ->
        PostWithNumberId.find {where: {id: p1.id}}, (err, p) ->
          should.not.exist(err)
          should.exist(p && p[0])
          p.length.should.be.equal(1)
          p[0].id.should.be.eql(p1.id)

          done()

  it 'should allow to find by number id using where inq', (done) ->
    PostWithNumberId.create {id: 1, title: 'Post1', content: 'Post1 content'}, (err, p1) ->
      PostWithNumberId.create {id: 2, title: 'Post2', content: 'Post2 content'}, (err, p2) ->
        PostWithNumberId.find {where: {id: {inq: [1]}}}, (err, p) ->
          should.not.exist(err)
          should.exist(p && p[0])
          p.length.should.be.equal(1)
          p[0].id.should.be.eql(p1.id)
        PostWithNumberId.find {where: {id: {inq: [1, 2]}}}, (err, p) ->
          should.not.exist(err)
          p.length.should.be.equal(2)
          p[0].id.should.be.eql(p1.id)
          p[1].id.should.be.eql(p2.id)
        PostWithNumberId.find {where: {id: {inq: [0]}}}, (err, p) ->
          should.not.exist(err)
          p.length.should.be.equal(0)

      done()

  it 'save should not return arangodb _key', (done) ->
    Post.create {title: 'Post1', content: 'Post content'}, (err, post) ->
      post.content = 'AAA'
      post.save (err, p) ->
        should.not.exist(err)
        should.not.exist(p._key)
        p.id.should.be.equal(post.id)
        p.content.should.be.equal('AAA')

        done()

  it 'find should return an object with an id, which is instanceof String, but not arangodb _key', (done) ->
    Post.create {title: 'Post1', content: 'Post content'}, (err, post) ->
      Post.findById post.id, (err, post) ->
        should.not.exist(err)
        post.id.should.be.an.instanceOf(String)
        should.not.exist(post._key)

        done()
