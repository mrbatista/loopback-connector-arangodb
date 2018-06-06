module.exports = require('should');

DataSource = require('loopback-datasource-juggler').DataSource

TEST_ENV = process.env.TEST_ENV or 'test'
config = require('rc')('loopback', { test: { arangodb: {}}})[TEST_ENV].arangodb;

calculateArangoDBVersion = (version) ->
  if !version then return 30000

  version = version.split '.'
  major = Number version[0];
  minor = Number version[1];

  return major * 10000 + minor * 1000

if process.env.CI
  ARANGODB_VERSION = calculateArangoDBVersion process.env.ARANGODB_VERSION
  config =
    host: process.env.ARANGODB_HOST or 'localhost'
    port: process.env.ARANGODB_PORT or 8529
    database: process.env.ARANGODB_DATABASE or '_system'
    arangoVersion: ARANGODB_VERSION

global.config = config;

global.getDataSource = global.getSchema = (customConfig) ->
  db = new DataSource(require('../src/arangodb'), customConfig or config);
  db.log = (msg) -> console.log msg
  return db

global.connectorCapabilities = {
  ilike: false,
  nilike: false,
  nestedProperty: true,
};
