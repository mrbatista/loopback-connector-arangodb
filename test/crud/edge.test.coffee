## This test written in mocha+should.js
should = require('./../init');

describe 'edge', () ->
  db = null
  User = null
  Friend = null
  FriendCustom = null

  before (done) ->
    db = getDataSource()

    User = db.define('User', {
      fullId: {type: String, _id: true},
      name: {type: String}
      email: {type: String},
      age: Number,
    }, updateOnLoad: true);

    Friend = db.define('Friend', {
      _id: {type: String, _id: true},
      _from: {type: String, _from: true},
      _to: {type: String, _to: true},
      label: {type: String}
    }, {updateOnLoad: true, arangodb: {edge: true}});

    FriendCustom = db.define('FriendCustom', {
      fullId: {type: String, _id: true},
      from: {type: String, _from: true, required: true},
      to: {type: String, _to: true, required: true},
      label: {type: String}
    }, {
      updateOnLoad: true,
      arangodb: {
        collection: 'Friend',
        edge: true
      }
    });

    db.automigrate done;

  beforeEach (done) ->
    User.destroyAll ->
      Friend.destroyAll done

  after (done) ->
    User.destroyAll ->
      Friend.destroyAll done
    
  it 'should report error create edge without field `_to`', (done) ->
    User.create [{name: 'Matteo'}, {name: 'Antonio'}], (err, users) ->
      return done err if err
      users.should.have.length(2)
      Friend.create {_from: users[0].fullId, label: 'friend'}, (err) ->
        should.exist(err)
        err.name.should.equal('ArangoError')
        err.code.should.equal(400)
        err.message.should.match(/^\'to\' is missing, expecting/)
        done()

  it 'should report error create edge without field `_from`', (done) ->
    User.create [{name: 'Matteo'}, {name: 'Antonio'}], (err, users) ->
      return done err if err
      users.should.have.length(2)
      Friend.create {_to: users[0].fullId, label: 'friend'}, (err) ->
        should.exist(err)
        err.name.should.equal('ArangoError')
        err.code.should.equal(400)
        err.message.should.match(/^\'from\' is missing, expecting/)
        done()

  it 'create edge should return default fields _to and _from', (done) ->
    User.create [{name: 'Matteo'}, {name: 'Antonio'}], (err, users) ->
      return done err if err
      users.should.have.length(2)
      Friend.create {_from: users[0].fullId, _to: users[1].fullId, label: 'friend'}, (err, friend) ->
        return done err if err
        should.exist(friend)
        should.exist(friend.id)
        should.exist(friend._id)
        friend._from.should.equal(users[0].fullId)
        friend._to.should.equal(users[1].fullId)
        friend.label.should.equal('friend')
        done()

  it 'create edge should return custom fields `to` and `from` defined as `_to` and `_from`', (done) ->
    User.create [{name: 'Matteo'}, {name: 'Antonio'}], (err, users) ->
      return done err if err
      users.should.have.length(2)
      FriendCustom.create {from: users[1].fullId, to: users[0].fullId, label: 'friend'}, (err, friend) ->
        return done err if err
        should.exist(friend)
        should.exist(friend.id)
        should.exist(friend.fullId)
        friend.from.should.equal(users[1].fullId)
        friend.to.should.equal(users[0].fullId)
        friend.label.should.equal('friend')
        done()
