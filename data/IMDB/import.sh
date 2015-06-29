#!/usr/bin/env bash
#!/bin/bash

${ARANGODB_BIN}arangosh --server.username=connector --server.password=connector --server.database=ConnectorTest --quiet <<EOF
  var db = require("org/arangodb").db;
  var Graph = require("org/arangodb/graph").Graph;
  db._drop("imdb_vertices");
  db._drop("imdb_edges");
  try { db._graphs.remove("imdb"); } catch (err) {}
  new Graph("imdb", "imdb_vertices", "imdb_edges"); 
EOF

${ARANGODB_BIN}arangorestore --server.username=connector --server.password=connector --server.database=ConnectorTest dump
