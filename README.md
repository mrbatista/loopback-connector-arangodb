# loopback-connector-arangodb

[![tag][tag-image]][tag-url]
[![build][travis-image]][travis-url]
[![Coverage Status][coverage-image]][coverage-url]
[![license:mit](https://img.shields.io/badge/license-mit-green.svg)](#license)
<br>
[![npm][npm-image]][npm-url]
[![npm downloads][npm-downloads-image]][npm-downloads-url]
[![dependencies][dep-status-image]][dep-status-url]
[![devDependency][dev-dep-status-image]][dev-dep-status-url]

The ArangoDB connector for the LoopBack framework.

## Customizing ArangoDB configuration for tests/examples

By default, examples and tests from this module assume there is a ArangoDB server
instance running on localhost at port 8529.

To customize the settings, you can drop in a `.loopbackrc` file to the root directory
of the project or the home folder.

**Note**: Tests and examples in this project configure the data source using the deprecated '.loopbackrc' file method,
which is not suppored in general.
For information on configuring the connector in a LoopBack application, please refer to [LoopBack documentation](http://docs.strongloop.com/display/LB/MongoDB+connector).

The .loopbackrc file is in JSON format, for example:

    {
        "dev": {
            "arangodb": {
                "host": "127.0.0.1",
                "database": "test",
                "username": "youruser",
                "password": "yourpass",
                "port": 8529
            }
        },
        "test": {
            "arangodb": {
                "host": "127.0.0.1",
                "database": "test",
                "username": "youruser",
                "password": "yourpass",
                "port": 8529
            }
        }
    }

**Note**: username/password is only required if the ArangoDB server has
authentication enabled.

## Contributing

**We love contributions!**

When contributing, follow the simple rules:

* Don't violate [DRY](http://programmer.97things.oreilly.com/wiki/index.php/Don%27t_Repeat_Yourself) principles.
* [Boy Scout Rule](http://programmer.97things.oreilly.com/wiki/index.php/The_Boy_Scout_Rule) needs to have been applied.
* Your code should look like all the other code – this project should look like it was written by one man, always.
* If you want to propose something – just create an issue and describe your question with as much description as you can.
* If you think you have some general improvement, consider creating a pull request with it.
* If you add new code, it should be covered by tests. No tests – no code.
* If you add a new feature, don't forget to update the documentation for it.
* If you find a bug (or at least you think it is a bug), create an issue with the library version and test case that we can run and see what are you talking about, or at least full steps by which we can reproduce it.

## Running tests

The tests in this repository are mainly integration tests, meaning you will need
to run them using our preconfigured test server.

1. Ask a core developer for instructions on how to set up test server
   credentials on your machine
2. `npm test`

## Release notes

## License

[MIT](LICENSE)

[tag-image]: https://img.shields.io/github/tag/mrbatista/loopback-connector-arangodb.svg
[tag-url]: https://github.com/mrbatista/loopback-connector-arangodb/releases
[npm-image]: https://img.shields.io/npm/v/loopback-connector-arangodb.svg
[npm-url]: https://npmjs.org/package/loopback-connector-arangodb
[npm-downloads-image]: https://img.shields.io/npm/dm/loopback-connector-arangodb.svg
[npm-downloads-url]: https://npmjs.org/package/loopback-connector-arangodb
[dep-status-image]: https://img.shields.io/david/mrbatista/loopback-connector-arangodb.svg
[dep-status-url]: https://david-dm.org/mrbatista/loopback-connector-arangodb
[dev-dep-status-image]: https://david-dm.org/mrbatista/loopback-connector-arangodb/dev-status.svg
[dev-dep-status-url]: https://david-dm.org/mrbatista/loopback-connector-arangodb#info=devDependencies
[travis-image]: https://travis-ci.org/mrbatista/loopback-connector-arangodb.svg
[travis-url]: https://travis-ci.org/mrbatista/loopback-connector-arangodb
[coverage-image]: https://coveralls.io/repos/github/mrbatista/loopback-connector-arangodb/badge.svg
[coverage-url]: https://coveralls.io/github/mrbatista/loopback-connector-arangodb