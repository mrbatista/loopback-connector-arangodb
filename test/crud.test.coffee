# This test written in mocha+should.js
describe 'arangodb connector crud', () ->

  require('./crud/document.test')
  require('./crud/edge.test')

