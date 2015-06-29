#!/usr/bin/env bash
${ARANGODB_BIN}arangosh --server.username=connector --server.password=connector --server.database=ConnectorTest --quiet <<EOF
  var db = require("org/arangodb").db;
  var Graph = require("org/arangodb/graph").Graph;
  
  db._drop("users");
EOF
arangoimp --file data.json --server.username=connector --server.password=connector --server.database=ConnectorTest --collection=users --create-collection=true --type=json
