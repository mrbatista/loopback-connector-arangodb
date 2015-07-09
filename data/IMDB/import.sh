#!/usr/bin/env bash
. ../json.sh

host="$(json_key 'test' 'arangodb' 'host' < ../../.loopbackrc)"
port="$(json_key 'test' 'arangodb' 'port' < ../../.loopbackrc)"
database="$(json_key 'test' 'arangodb' 'database' < ../../.loopbackrc)"
username="$(json_key 'test' 'arangodb' 'username' < ../../.loopbackrc)"
password="$(json_key 'test' 'arangodb' 'password' < ../../.loopbackrc)"

cmd_parameters=''
# set url=host:port, connect via tcp
if [ -z "$host" ] | [ -z "$port" ]
then
  cmd_parameters+=''
else
  cmd_parameters+="--server.endpoint=tcp://$host:$port "
fi

# set database
if [ -z "$database" ]
then
  cmd_parameters+=''
else
  cmd_parameters+="--server.database=$database "
fi

# username
if [ -z "$username" ]
then
  cmd_parameters+=''
else
  cmd_parameters+="--server.username=$username "
fi

# password
if [ -z "$password" ]
then
  cmd_parameters+=''
else
  cmd_parameters+="--server.password=$password "
fi


${ARANGODB_BIN}arangosh $cmd_parameters --quiet <<EOF
  var db = require("org/arangodb").db;
  var Graph = require("org/arangodb/graph").Graph;
  db._drop("imdb_vertices");
  db._drop("imdb_edges");
  try { db._graphs.remove("imdb"); } catch (err) {}
  new Graph("imdb", "imdb_vertices", "imdb_edges"); 
EOF

${ARANGODB_BIN}arangorestore $cmd_parameters dump
