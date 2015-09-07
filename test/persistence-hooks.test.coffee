should = require('./init')
suite = require('loopback-datasource-juggler/test/persistence-hooks.suite.js')

suite(global.getDataSource(), should)
