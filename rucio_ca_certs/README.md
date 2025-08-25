# ESCAPE Rucio Instance CA Certificates

ESCAPE Rucio Instance CA generation certificates script.

You should be able to find the `rucio_ca.pem` file within the `/cvmfs/sw.escape.sw/etc/ssl/certs/` directory.

## Certificate generation

### Certificate file

1. Clone this repository.
2. Make sure you have `curl` installed.
3. Either;
    * Go to the `rucio_ca_certs` directory and run the `generate_certs.sh` file.
    * If you are a CMVFS administrator, you can check and run `rucio_ca_certs-cvmfs-updater.sh`.

### Within a `Dockerfile`

You can add the following snippet to your `Dockerfile`.
```Dockerfile
RUN mkdir /certs \
    && touch /certs/rucio_ca.pem \
    && curl -fsSL 'https://cafiles.cern.ch/cafiles/certificates/CERN%20Root%20Certification%20Authority%202.crt' | openssl x509 -inform DER -out /tmp/cernrootca2.crt \
    && curl -fsSL 'https://cafiles.cern.ch/cafiles/certificates/CERN%20Grid%20Certification%20Authority(1).crt' -o /tmp/cerngridca.crt \
    && curl -fsSL 'https://cafiles.cern.ch/cafiles/certificates/CERN%20Certification%20Authority.crt' -o /tmp/cernca.crt \
    && cat /tmp/cernrootca2.crt >> /certs/rucio_ca.pem \
    && cat /tmp/cerngridca.crt >> /certs/rucio_ca.pem \
    && cat /tmp/cernca.crt >> /certs/rucio_ca.pem \
    && rm /tmp/*.crt
```