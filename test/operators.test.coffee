moment = require('moment')

should = require('./init');

describe 'operators', () ->
  db = null
  User = null

  before (done) ->
    db = getDataSource()

    User = db.define 'User', {
      name: String,
      email: String,
      age: Number,
      created: Date,
    }
    User.destroyAll(done)
  
  describe 'between', () ->

    beforeEach () -> User.destroyAll()

    it 'found data that match operator criteria - date type', (done) ->
      now = moment().toDate();
      beforeTenHours = moment(now).subtract({hours: 10}).toDate()
      afterTenHours = moment(now).add({hours: 10}).toDate()

      usersData = [
        {name: 'Matteo', created: now},
        {name: 'Antonio', created: beforeTenHours},
        {name: 'Daniele', created: afterTenHours},
        {name: 'Mariangela'},
      ]

      User.create usersData, (err, users) ->
        return done err if err
        users.should.have.lengthOf(4)
        filter = {where: {created: {between: [beforeTenHours, afterTenHours]}}}
        User.find filter, (err, users) ->
          return done err if err
          users.should.have.lengthOf(3)
          filter = {where: {created: {between: [now, afterTenHours]}}}
          User.find filter, (err, users) ->
            return done err if err
            users.should.have.lengthOf(2)
            done()
