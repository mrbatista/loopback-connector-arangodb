should = require('./init')
suite = require('loopback-datasource-juggler/test/persistence-hooks.suite')

suite(global.getDataSource(), should)
