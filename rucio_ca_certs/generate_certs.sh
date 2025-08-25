#!/usr/bin/env bash
# Copyright European Organization for Nuclear Research (CERN)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# You may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#                       http://www.apache.org/licenses/LICENSE-2.0
#
# Authors:
# - Enrique Garcia, <giovanin.guerrieri@cern.ch>, 2025
# - Giovanni Guerrieri, <giovanin.guerrieri@cern.ch>, 2025

echo "General: Generating rucio_ca.pem file"

touch rucio_ca.pem 

echo "General: Downloading *.pem files"

curl -fsSL 'https://cafiles.cern.ch/cafiles/certificates/CERN%20Root%20Certification%20Authority%202.crt' | openssl x509 -inform DER -out cernrootca2.crt 
curl -fsSL 'https://cafiles.cern.ch/cafiles/certificates/CERN%20Grid%20Certification%20Authority(1).crt' -o cerngridca.crt 
curl -fsSL 'https://cafiles.cern.ch/cafiles/certificates/CERN%20Certification%20Authority.crt' -o cernca.crt 

echo "General: Creating the bundle cert file"

cat cernrootca2.crt >> rucio_ca.pem 
cat cerngridca.crt >> rucio_ca.pem \
cat cernca.crt >> rucio_ca.pem \

echo "General: Removing tmp files"

rm *.crt

echo "INFO: This is a bundle certificates file. You can add it to the `/etc/ssl/certs/` directory"

echo "General: DONE!"
# Provide the command to upload the tarball to a remote server
# echo "scp rucio_ca.pem ${USER}@lxplus:~/public/rucio_certs"