module.exports = require('should');

# define global method getDataSource/getSchema, callable with a custom config, falling back to a config that was defined in a .loopbackrc file
global.getDataSource = global.getSchema = (customConfig) ->
  console.log customConfig
  DataSource = require('loopback-datasource-juggler').DataSource;
  
  # get fallback config from .loopbackrc
  rc_defaults =
    test:
      arangodb: {}
  
  config = require('rc')('loopback', rc_defaults).test.arangodb
  
  db = new DataSource(require('../'), customConfig || config);

  db.log = (msg) -> console.log msg

  return db
