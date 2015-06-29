#!/usr/bin/env bash
${ARANGODB_BIN}arangosh --server.username=connector --server.password=connector --server.database=ConnectorTest --quiet <<EOF
  var db = require("org/arangodb").db;
  var Graph = require("org/arangodb/graph").Graph;
  
  db._drop("airports");
EOF
arangoimp --file data.csv --server.username=connector --server.password=connector --server.database=ConnectorTest --collection=airports --create-collection=true --type=csv