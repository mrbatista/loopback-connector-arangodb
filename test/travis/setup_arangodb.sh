#!/bin/bash

VERSION=$ARANGODB_VERSION
FILE_SETUP_ARANGODB=setup_arangodb_$VERSION.sh

curl -s -L "https://www.arangodb.com/repositories/travisCI/$FILE_SETUP_ARANGODB" -o "$FILE_SETUP_ARANGODB"
chmod +x "$FILE_SETUP_ARANGODB"
"./$FILE_SETUP_ARANGODB"