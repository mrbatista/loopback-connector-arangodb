# This test written in mocha+should.js
should = require('./../init');

describe 'crud document:', () ->
  db = null
  User = null
  Post = null
  Product = null
  PostWithNumberId = null
  PostWithStringId = null
  PostWithStringKey = null
  PostWithNumberUnderscoreId = null
  Name = null

  before (done) ->
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

    Post = db.define('Post', {
      title: {type: String, length: 255, index: true},
      content: {type: String},
      comments: [String]
    });

    Product = db.define('Product', {
      name: {type: String, length: 255, index: true},
      description: {type: String},
      price: {type: Number},
      pricehistory: {type: Object}
    });

    PostWithStringId = db.define('PostWithStringId', {
      id: {type: String, id: true},
      title: { type: String, length: 255, index: true },
      content: { type: String }
    });

    PostWithStringKey = db.define('PostWithStringKey', {
      _key: {type: String, id: true},
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

    Name = db.define('Name', {}, {});

    User.hasMany(Post);
    Post.belongsTo(User);

    db.automigrate(['User', 'Post', 'Product', 'PostWithStringId', 'PostWithStringKey',
                    'PostWithNumberUnderscoreId','PostWithNumberId'], done)

  beforeEach (done) ->
    User.settings.arangodb = {};
    User.destroyAll ->
      Post.destroyAll ->
        PostWithNumberId.destroyAll ->
          PostWithNumberUnderscoreId.destroyAll ->
            PostWithStringId.destroyAll ->
              PostWithStringKey.destroyAll(done)

  it 'should handle correctly type Number for id field _id', (done) ->
    PostWithNumberUnderscoreId.create {_id: 3, content: 'test'}, (err, person) ->
      should.not.exist(err)
      person._id.should.be.equal(3)
      PostWithNumberUnderscoreId.findById person._id, (err, p) ->
        should.not.exist(err)
        p.content.should.be.equal('test')

        done()

  it 'should handle correctly type Number for id field _id using String', (done) ->

    PostWithNumberUnderscoreId.create {_id: 4, content: 'test'}, (err, person) ->
      should.not.exist(err)
      person._id.should.be.equal(4);
      PostWithNumberUnderscoreId.findById '4', (err, p) ->
        should.not.exist(err)
        p.content.should.be.equal('test');

        done()

  it 'should allow to find post by id string if `_id` is defined id', (done) ->

    PostWithNumberUnderscoreId.create (err, post) ->
      PostWithNumberUnderscoreId.find {where: {_id: post._id.toString()}}, (err, p) ->
        should.not.exist(err)
        post = p[0]
        should.exist(post)
        post._id.should.be.an.instanceOf(Number);

      done()

  it 'find with `_id` as defined id should return an object with _id instanceof String', (done) ->

    PostWithNumberUnderscoreId.create (err, post) ->
      PostWithNumberUnderscoreId.findById post._id, (err, post) ->
        should.not.exist(err)
        post._id.should.be.an.instanceOf(Number)

        done()

  it 'should update the instance with `_id` as defined id', (done) ->

    PostWithNumberUnderscoreId.create {title: 'a', content: 'AAA'}, (err, post) ->
      post.title = 'b'
      PostWithNumberUnderscoreId.updateOrCreate post, (err, p) ->
        should.not.exist(err)
        p._id.should.be.equal(post._id)
        PostWithNumberUnderscoreId.findById post._id, (err, p) ->
          should.not.exist(err)
          p._id.should.be.eql(post._id)
          p.content.should.be.equal(post.content)
          p.title.should.be.equal('b')
          PostWithNumberUnderscoreId.find {where: {title: 'b'}}, (err, posts) ->
            should.not.exist(err)
            p = posts[0]
            p._id.should.be.eql(post._id)
            p.content.should.be.equal(post.content)
            p.title.should.be.equal('b')
            posts.should.have.lengthOf(1)

            done()

  it 'all should return object (with `_id` as defined id) with an _id instanceof String', (done) ->

    post = new PostWithNumberUnderscoreId({title: 'a', content: 'AAA'})
    post.save (err, post) ->
      PostWithNumberUnderscoreId.all {where: {title: 'a'}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.lengthOf(1)
        post = posts[0]
        post.should.have.property('title', 'a')
        post.should.have.property('content', 'AAA')
        post._id.should.be.an.instanceOf(Number)

        done()

  it 'all return should honor filter.fields, with `_id` as defined id', (done) ->

    post = new PostWithNumberUnderscoreId {title: 'a', content: 'AAA'}
    post.save (err, post) ->
      PostWithNumberUnderscoreId.all {fields: ['title'], where: {title: 'a'}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.lengthOf(1)
        post = posts[0]
        post.should.have.property('title', 'a')
        post.should.have.property('content', undefined)
        should.not.exist(post._id)

        done()

  it 'should allow to find post by id string if `_key` is defined id', (done) ->

    PostWithStringKey.create (err, post) ->
      PostWithStringKey.find {where: {_key: post._key.toString()}}, (err, p) ->
        should.not.exist(err)
        post = p[0]
        should.exist(post)
        post._key.should.be.an.instanceOf(String);

      done()

  it 'find with `_key` as defined id should return an object with _key instanceof String', (done) ->

    PostWithStringKey.create (err, post) ->
      PostWithStringKey.findById post._key, (err, post) ->
        should.not.exist(err)
        post._key.should.be.an.instanceOf(String)
        done()

  it 'should update the instance with `_key` as defined id', (done) ->

    PostWithStringKey.create {title: 'a', content: 'AAA'}, (err, post) ->
      post.title = 'b'
      PostWithStringKey.updateOrCreate post, (err, p) ->
        should.not.exist(err)
        p._key.should.be.equal(post._key)
        PostWithStringKey.findById post._key, (err, p) ->
          should.not.exist(err)
          p._key.should.be.eql(post._key)
          p.content.should.be.equal(post.content)
          p.title.should.be.equal('b')
          PostWithStringKey.find {where: {title: 'b'}}, (err, posts) ->
            should.not.exist(err)
            p = posts[0]
            p._key.should.be.eql(post._key)
            p.content.should.be.equal(post.content)
            p.title.should.be.equal('b')
            posts.should.have.lengthOf(1)

            done()

  it 'all should return object (with `_key` as defined id) with an _key instanceof String', (done) ->

    post = new PostWithStringKey({title: 'a', content: 'AAA'})
    post.save (err, post) ->
      PostWithStringKey.all {where: {title: 'a'}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.lengthOf(1)
        post = posts[0]
        post.should.have.property('title', 'a')
        post.should.have.property('content', 'AAA')
        post._key.should.be.an.instanceOf(String)

        done()

  it 'all return should honor filter.fields, with `_key` as defined id', (done) ->

    post = new PostWithStringKey {title: 'a', content: 'AAA'}
    post.save (err, post) ->
      PostWithStringKey.all {fields: ['title'], where: {title: 'a'}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.lengthOf(1)
        post = posts[0]
        post.should.have.property('title', 'a')
        post.should.have.property('content', undefined)
        should.not.exist(post._key)

        done()

  it 'should have created simple User models', (done) ->

    User.create {age: 3, content: 'test'}, (err, user) ->
      should.not.exist(err)
      user.age.should.be.equal(3)
      user.content.should.be.equal('test')
      user.id.should.not.be.null
      should.not.exists user._key

      done()

  it 'should support Buffer type', (done) ->
    User.create {name: 'John', icon: new Buffer('1a2')}, (err, u)  ->
      User.findById u.id, (err, user) ->
        should.not.exist(err)
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

      events = []
      connector = Post.getDataSource().connector
      connector.observe 'before execute', (ctx, next) ->
        ctx.req.command.should.be.string;
        ctx.req.params.should.be.array;
        events.push('before execute ' + ctx.req.command);
        next()

      connector.observe 'after execute', (ctx, next) ->
        ctx.res.should.be.object;
        events.push('after execute ' + ctx.req.command);
        next()

      Post.create {title: 'Post1', content: 'Post1 content'}, (err, p1) ->
        Post.find (err, results) ->
          events.should.eql(['before execute save', 'after execute save',
            'before execute document', 'after execute document'])
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

  it 'save should not return arangodb _key and _rev', (done) ->
    Post.create {title: 'Post1', content: 'Post content'}, (err, post) ->
      post.content = 'AAA'
      post.save (err, p) ->
        should.not.exist(err)
        should.not.exist(p._key)
        should.not.exist(p._rev)
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


  it 'should update attribute of the specific instance', (done) ->

    User.create {name: 'Al', age: 31, email:'al@'}, (err, createdusers) ->
      createdusers.updateAttributes {age: 32, email:'al@strongloop'}, (err, updated) ->
        should.not.exist(err)
        updated.age.should.be.equal(32)
        updated.email.should.be.equal('al@strongloop')
        done()

  # MEMO: Import data present into data/users/names_100000.json before running this test.
  it.skip 'cursor should returns all documents more then max single default size (1000) ', (done) ->

  # Increase timeout only for this test
    this.timeout(20000);
    Name.find (err, names) ->
      should.not.exist(err)
      names.length.should.be.equal(100000)
      done()

  it.skip 'cursor should returns all documents more then max single default cursor size (1000) and respect limit filter ', (done) ->

  # Increase timeout only for this test
    this.timeout(20000);
    Name.find {limit: 1002}, (err, names) ->
      should.not.exist(err)
      names.length.should.be.equal(1002)
      done()

  describe 'updateAll', () ->

    it 'should update the instance matching criteria', (done) ->

      User.create {name: 'Al', age: 31, email:'al@strongloop'}, (err, createdusers) ->
        User.create {name: 'Simon', age: 32,  email:'simon@strongloop'}, (err, createdusers) ->
          User.create {name: 'Ray', age: 31,  email:'ray@strongloop'}, (err, createdusers) ->
            User.updateAll {age:31},{company:'strongloop.com'}, (err, updatedusers) ->
              should.not.exist(err)
              updatedusers.should.have.property('count', 2);
              User.find {where:{age:31}}, (err2, foundusers) ->
                should.not.exist(err2)
                foundusers[0].company.should.be.equal('strongloop.com')
                foundusers[1].company.should.be.equal('strongloop.com')

                done()


  it 'updateOrCreate should update the instance', (done) ->

    Post.create {title: 'a', content: 'AAA'}, (err, post) ->
      post.title = 'b'

      Post.updateOrCreate post, (err, p) ->
        should.not.exist(err)
        p.id.should.be.equal(post.id)
        p.content.should.be.equal(post.content)
        should.not.exist(p._key)

        Post.findById post.id, (err, p) ->
          p.id.should.be.eql(post.id)
          should.not.exist(p._key)
          p.content.should.be.equal(post.content)
          p.title.should.be.equal('b')

        done()

  it 'updateOrCreate should update the instance without removing existing properties', (done) ->

    Post.create {title: 'a', content: 'AAA', comments: ['Comment1']}, (err, post) ->
      post = post.toObject()
      delete post.title
      delete post.comments;
      Post.updateOrCreate post, (err, p) ->
        should.not.exist(err)
        p.id.should.be.equal(post.id)
        p.content.should.be.equal(post.content)
        should.not.exist(p._key)

        Post.findById post.id, (err, p) ->
          p.id.should.be.eql(post.id)
          should.not.exist(p._key)
          p.content.should.be.equal(post.content)
          p.title.should.be.equal('a')
          p.comments[0].should.be.equal('Comment1')

          done()

  it 'updateOrCreate should create a new instance if it does not exist', (done) ->

    post = {id: '123', title: 'a', content: 'AAA'};
    Post.updateOrCreate post, (err, p) ->
      should.not.exist(err)
      p.title.should.be.equal(post.title)
      p.content.should.be.equal(post.content)
      p.id.should.be.eql(post.id)

      Post.findById p.id, (err, p) ->
        p.id.should.be.equal(post.id)
        should.not.exist(p._key)
        p.content.should.be.equal(post.content)
        p.title.should.be.equal(post.title)
        p.id.should.be.equal(post.id)

        done()

  it 'save should update the instance with the same id', (done) ->

    Post.create {title: 'a', content: 'AAA'}, (err, post) ->
      post.title = 'b';
      post.save (err, p) ->
        should.not.exist(err)
        p.id.should.be.equal(post.id)
        p.content.should.be.equal(post.content)
        should.not.exist(p._key)

        Post.findById post.id, (err, p) ->
          p.id.should.be.eql(post.id)
          should.not.exist(p._key)
          p.content.should.be.equal(post.content)
          p.title.should.be.equal('b')

          done()

  it 'save should update the instance without removing existing properties', (done) ->

    Post.create {title: 'a', content: 'AAA'}, (err, post) ->
      delete post.title
      post.save (err, p) ->
        should.not.exist(err)
        p.id.should.be.equal(post.id)
        p.content.should.be.equal(post.content)
        should.not.exist(p._key)

        Post.findById post.id, (err, p) ->
          p.id.should.be.eql(post.id)
          should.not.exist(p._key)
          p.content.should.be.equal(post.content)
          p.title.should.be.equal('a')

          done()

  it 'save should create a new instance if it does not exist', (done) ->

    post = new Post {id: '123', title: 'a', content: 'AAA'}
    post.save post, (err, p) ->
      should.not.exist(err)
      p.title.should.be.equal(post.title);
      p.content.should.be.equal(post.content);
      p.id.should.be.equal(post.id)

      Post.findById p.id, (err, p) ->
        p.id.should.be.equal(post.id)
        should.not.exist(p._key)
        p.content.should.be.equal(post.content)
        p.title.should.be.equal(post.title)
        p.id.should.be.equal(post.id)

        done()

  it 'all should return object with an id, which is instanceof String, but not arangodb _key', (done) ->

    post = new Post {title: 'a', content: 'AAA'}
    post.save (err, post) ->
      Post.all {where: {title: 'a'}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.lengthOf(1)
        post = posts[0]
        post.should.have.property('title', 'a')
        post.should.have.property('content', 'AAA')
        post.id.should.be.an.instanceOf(String)
        should.not.exist(post._key)

        done()

  it 'all return should honor filter.fields', (done) ->

    post = new Post {title: 'b', content: 'BBB'}
    post.save (err, post) ->
      Post.all {fields: ['title'], where: {content: 'BBB'}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.lengthOf(1)
        post = posts[0]
        post.should.have.property('title', 'b')
        post.should.have.property('content', undefined)
        should.not.exist(post._key)
        should.not.exist(post.id)

        done()

  it 'find should order by id if the order is not set for the query filter', (done) ->

    PostWithStringId.create {id: '2', title: 'c', content: 'CCC'}, (err, post) ->
      PostWithStringId.create {id: '1', title: 'd', content: 'DDD'}, (err, post) ->
        PostWithStringId.find (err, posts) ->
          should.not.exist(err)
          posts.length.should.be.equal(2)
          posts[0].id.should.be.equal('1')

          PostWithStringId.find {limit: 1, offset: 0}, (err, posts) ->
            should.not.exist(err)
            posts.length.should.be.equal(1)
            posts[0].id.should.be.equal('1')

            PostWithStringId.find {limit: 1, offset: 1}, (err, posts) ->
              should.not.exist(err)
              posts.length.should.be.equal(1)
              posts[0].id.should.be.equal('2')

              done()

  it 'order by specific query filter', (done) ->

    PostWithStringId.create {id: '2', title: 'c', content: 'CCC'}, (err, post) ->
      PostWithStringId.create {id: '1', title: 'd', content: 'DDD'}, (err, post) ->
        PostWithStringId.create {id: '3', title: 'd', content: 'AAA'}, (err, post) ->
          PostWithStringId.find {order: ['title DESC', 'content ASC']}, (err, posts) ->
            posts.length.should.be.equal(3)
            posts[0].id.should.be.equal('3')

            PostWithStringId.find {order: ['title DESC', 'content ASC'], limit: 1, offset: 0}, (err, posts) ->
              should.not.exist(err)
              posts.length.should.be.equal(1)
              posts[0].id.should.be.equal('3')

              PostWithStringId.find {order: ['title DESC', 'content ASC'], limit: 1, offset: 1}, (err, posts) ->
                should.not.exist(err)
                posts.length.should.be.equal(1)
                posts[0].id.should.be.equal('2')

              PostWithStringId.find {order: ['title DESC', 'content ASC'], limit: 1, offset: 2}, (err, posts) ->
                should.not.exist(err)
                posts.length.should.be.equal(1)
                posts[0].id.should.be.equal('1')

                done()

  it 'should report error on duplicate keys', (done) ->

    Post.create {title: 'd', content: 'DDD'}, (err, post) ->
      Post.create {id: post.id, title: 'd', content: 'DDD'}, (err, post) ->
        should.exist(err)

        done()

  it 'should allow to find using like', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {title: {like: 'M%st'}}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 1)

        done()

  it 'should allow to find using case insensitive like', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {title: {like: 'm%st', options: 'i'}}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 1)

        done()

  it 'should allow to find using case insensitive like', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {content: {like: 'HELLO', options: 'i'}}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 1)

        done()

  it 'should support like for no match', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {title: {like: 'M%XY'}}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 0)

        done()

  it 'should allow to find using nlike', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {title: {nlike: 'M%st'}}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 0)

        done()

  it 'should allow to find using case insensitive nlike', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {title: {nlike: 'm%st', options: 'i'}}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 0)

        done()

  it 'should support nlike for no match', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {title: {nlike: 'M%XY'}}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 1)

        done()
  #
  it 'should support "and" operator that is satisfied', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {and: [{title: 'My Post'}, {content: 'Hello'}]}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 1)

        done()

  it 'should support "and" operator that is not satisfied', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {and: [{title: 'My Post'}, {content: 'Hello1'}]}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 0)

        done()

  it 'should support "or" that is satisfied', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {or: [{title: 'My Post'}, {content: 'Hello1'}]}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 1)
        done()

  it 'should support "or" operator that is not satisfied', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {or: [{title: 'My Post1'}, {content: 'Hello1'}]}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 0)

        done()

  # TODO: Add support to "nor"
  #  it 'should support "nor" operator that is satisfied', (done) ->
  #
  #    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
  #      Post.find {where: {nor: [{title: 'My Post1'}, {content: 'Hello1'}]}}, (err, posts) ->
  #        should.not.exist(err)
  #        posts.should.have.property('length', 1)
  #
  #        done()
  #
  #  it 'should support "nor" operator that is not satisfied', (done) ->
  #
  #    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
  #      Post.find {where: {nor: [{title: 'My Post'}, {content: 'Hello1'}]}}, (err, posts) ->
  #        should.not.exist(err)
  #        posts.should.have.property('length', 0)
  #
  #        done()

  it 'should support neq for match', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {title: {neq: 'XY'}}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 1)

        done()

  it 'should support neq for no match', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.find {where: {title: {neq: 'My Post'}}}, (err, posts) ->
        should.not.exist(err)
        posts.should.have.property('length', 0)

        done()

  # The where object should be parsed by the connector
  it 'should support where for count', (done) ->

    Post.create {title: 'My Post', content: 'Hello'}, (err, post) ->
      Post.count {and: [{title: 'My Post'}, {content: 'Hello'}]}, (err, count) ->
        should.not.exist(err)
        count.should.be.equal(1)
        Post.count {and: [{title: 'My Post1'}, {content: 'Hello'}]}, (err, count) ->
          should.not.exist(err)
          count.should.be.equal(0)

          done()

  # The where object should be parsed by the connector
  it 'should support where for destroyAll', (done) ->

    Post.create {title: 'My Post1', content: 'Hello'}, (err, post) ->
      Post.create {title: 'My Post2', content: 'Hello'}, (err, post) ->
        Post.destroyAll {and: [
            {title: 'My Post1'},
            {content: 'Hello'}
          ]}, (err) ->
          should.not.exist(err)
          Post.count (err, count) ->
            should.not.exist(err)
            count.should.be.equal(1)

            done()
  #
  #  context 'regexp operator', () ->
  #    before () ->
  #      deleteExistingTestFixtures (done) ->
  #        Post.destroyAll(done)
  #
  #    beforeEach () ->
  #      createTestFixtures (done) ->
  #        Post.create [
  #          {title: 'a', content: 'AAA'},
  #          {title: 'b', content: 'BBB'}
  #        ], done
  #
  #    after () ->
  #      deleteTestFixtures (done) ->
  #        Post.destroyAll(done);
  #
  #    context 'with regex strings', () ->
  #      context 'using no flags', () ->
  #        it 'should work', (done) ->
  #          Post.find {where: {content: {regexp: '^A'}}}, (err, posts) ->
  #            should.not.exist(err)
  #            posts.length.should.equal(1)
  #            posts[0].content.should.equal('AAA')
  #            done()
  #
  #      context 'using flags', () ->
  #        beforeEach () ->
  #          addSpy () ->
  #            sinon.stub(console, 'warn');
  #
  #        afterEach () ->
  #          removeSpy ->
  #            console.warn.restore();
  #
  #        it 'should work', (done) ->
  #          Post.find {where: {content: {regexp: '^a/i'}}}, (err, posts) ->
  #            should.not.exist(err)
  #            posts.length.should.equal(1)
  #            posts[0].content.should.equal('AAA')
  #            done()
  #
  #        it 'should print a warning when the global flag is set', (done) ->
  #            Post.find {where: {content: {regexp: '^a/g'}}}, (err, posts) ->
  #              console.warn.calledOnce.should.be.ok
  #              done()
  #
  #    context 'with regex literals', () ->
  #      context 'using no flags', () ->
  #        it 'should work', (done) ->
  #          Post.find {where: {content: {regexp: /^A/}}}, (err, posts) ->
  #            should.not.exist(err)
  #            posts.length.should.equal(1)
  #            posts[0].content.should.equal('AAA')
  #            done()
  #
  #
  #      context 'using flags', () ->
  #        beforeEach () ->
  #          addSpy () ->
  #            sinon.stub(console, 'warn')
  #
  #        afterEach () ->
  #          removeSpy () ->
  #            console.warn.restore()
  #
  #
  #        it 'should work', (done) ->
  #          Post.find {where: {content: {regexp: /^a/i}}}, (err, posts) ->
  #            should.not.exist(err)
  #            posts.length.should.equal(1)
  #            posts[0].content.should.equal('AAA')
  #            done()
  #
  #        it 'should print a warning when the global flag is set', (done) ->
  #            Post.find {where: {content: {regexp: /^a/g}}}, (err, posts) ->
  #              console.warn.calledOnce.should.be.ok
  #              done()
  #
  #    context 'with regex object', () ->
  #      context 'using no flags', () ->
  #        it 'should work', (done) ->
  #          Post.find {where: {content: {regexp: new RegExp(/^A/)}}}, (err, posts) ->
  #            should.not.exist(err)
  #            posts.length.should.equal(1)
  #            posts[0].content.should.equal('AAA')
  #            done()
  #
  #
  #    context 'using flags', () ->
  #      beforeEach () ->
  #        addSpy () ->
  #          sinon.stub(console, 'warn')
  #
  #      afterEach () ->
  #        removeSpy () ->
  #          console.warn.restore()
  #
  #
  #      it 'should work', (done) ->
  #        Post.find {where: {content: {regexp: new RegExp(/^a/i)}}}, (err, posts) ->
  #          should.not.exist(err)
  #          posts.length.should.equal(1)
  #          posts[0].content.should.equal('AAA')
  #          done()
  #
  #      it 'should print a warning when the global flag is set', (done) ->
  #        Post.find {where: {content: {regexp: new RegExp(/^a/g)}}}, (err, posts) ->
  #          should.not.exist(err)
  #          console.warn.calledOnce.should.be.ok;
  #          done()

  after (done) ->
    User.destroyAll ->
      Post.destroyAll ->
        PostWithNumberId.destroyAll ->
          PostWithStringId.destroyAll ->
            PostWithStringKey.destroyAll ->
              PostWithNumberUnderscoreId.destroyAll(done)
