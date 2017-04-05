'use strict';

module.exports = (grunt) ->
# Load grunt tasks automatically
  require('load-grunt-tasks')(grunt)

  # Time how long tasks take. Can help when optimizing build times
  require('time-grunt')(grunt)

  grunt.loadNpmTasks('grunt-mocha-istanbul')

  # Project configuration
  grunt.initConfig
    # Metadata
    pkg: grunt.file.readJSON('package.json')

    banner: '/*! <%= pkg.name %> - v<%= pkg.version %> - ' +
      '<%= grunt.template.today("yyyy-mm-dd") %>\n' +
      '<%= pkg.homepage ? "* " + pkg.homepage + "\\n" : "" %>' +
      '* Copyright (c) <%= grunt.template.today("yyyy") %> <%= pkg.author.name %>;' +
      ' Licensed <%= pkg.license %> */\n'

    # Task configuration
    concat:
      options:
        banner: '<%= banner %>',
        stripBanners: true
      dist:
        src: ['lib/arangodb.js']
        dest: 'lib/arangodb.js'

    clean:
      test: ['build', 'coverage', 'lib']

    coffee:
      compile:
        options:
          sourceMap: true
        files:
          'lib/arangodb.js': 'src/arangodb.coffee'

    'mocha_istanbul':
      coverage:
        src: 'test'
        options:
          mask: '*.test.coffee'
          print: 'detail'
          reporter: 'dot'
          scriptPath: require.resolve('./node_modules/ibrik/bin/ibrik')

    istanbul_check_coverage:
      default:
        options:
          coverageFolder: 'coverage'
          check:
            lines: 60,
            statements: 60

    coveralls:
      options:
        force: false
      default:
        src: 'coverage/**/*.info'

  # Add eslint
  grunt.registerTask 'test', ['clean', 'mocha_istanbul', 'istanbul_check_coverage']

  # Build task
  grunt.registerTask 'build', (target) ->
    if target is 'dist'
      return grunt.task.run(['coffee:compile', 'concat:dist'])

    return grunt.task.run('coffee:compile')
