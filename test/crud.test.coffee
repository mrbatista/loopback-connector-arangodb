# This test written in mocha+should.js
describe 'arangodb connector:', () ->

  before () ->
    require('./init');

  require('./crud/document.test')
  require('./crud/edge.test')

