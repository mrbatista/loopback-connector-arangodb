describe 'arangodb imported features', () ->

  before () ->
    require('./init')

  require('loopback-datasource-juggler/test/common.batch.js')
  require('loopback-datasource-juggler/test/default-scope.test.js')
  require('loopback-datasource-juggler/test/include.test.js')
