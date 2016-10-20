module.exports = require('should');

DataSource = require('loopback-datasource-juggler').DataSource

TEST_ENV = process.env.TEST_ENV || 'test'
config = require('rc')('loopback', { test: { arangodb: {}}})[TEST_ENV].arangodb;

global.config = config;

if process.env.CI
  config =
    host: process.env.ARANGODB_HOST or 'localhost'
    port: process.env.ARANGODB_PORT or 8529
    database: '_system'
    #database: 'lb-ds-arangodb-test-' + (
      #process.env.TRAVIS_BUILD_NUMBER or process.env.BUILD_NUMBER or '1'),

global.getDataSource = global.getSchema = (customConfig) ->
  db = new DataSource(require('../'), customConfig || config);
  db.log = (msg) -> console.log msg

  return db
