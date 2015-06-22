module.exports = require('should');

DataSource = require('loopback-datasource-juggler').DataSource;

config = require('rc')('loopback', {test: {arangodb: {}}}).test.arangodb;

if (process.env.CI) {
  config = {
    host: 'localhost',
    database: 'lb-ds-arangodb-test-' + (process.env.TRAVIS_BUILD_NUMBER || process.env.BUILD_NUMBER || '1'),
  };
}

global.getDataSource = global.getSchema = function (customConfig) {
  var db = new DataSource(require('../'), customConfig || config);
  db.log = function (a) {
    console.log(a);
  };

  return db;
};
