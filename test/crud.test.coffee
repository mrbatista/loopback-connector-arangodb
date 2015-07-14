# This test written in mocha+should.js
should = require('./init');

describe 'arangodb crud functionality:', () ->
  ds = null
  SimpleModel = null
  before () ->
    ds = getDataSource()

    SimpleModel = ds.define 'SimpleModel', {
      name:
        type: String
    }, {
      options:
        arangodb:
          collection: 'SimpleModel'
    }

  it 'should have created simple models', (done) ->
    data = {'content': 'test'};
    SimpleModel.create data, (err, result) ->
      should.not.exist(err);
      should.exist(result);
      should.exist(result.id);
      result.content.should.be.equal('test')
      done();

