describe 'arangodb imported features', () ->

  before () ->
    require('./init')

  require('loopback-datasource-juggler/test/common.batch')
  require('loopback-datasource-juggler/test/default-scope.test')
  require('loopback-datasource-juggler/test/include.test')
