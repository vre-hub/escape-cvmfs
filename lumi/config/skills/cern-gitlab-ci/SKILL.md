---
name: cern-gitlab-ci
description: Help writing and debugging CERN GitLab CI/CD pipelines (.gitlab-ci.yml) with LCG releases and CVMFS
---

## What I do

Help set up and troubleshoot CI/CD pipelines on CERN GitLab (gitlab.cern.ch), including LCG software release usage, CVMFS access, and common HEP build patterns.

## Common CI patterns

### Using LCG releases from CVMFS
```yaml
build:
  image: gitlab-registry.cern.ch/linuxsupport/alma9-base
  tags:
    - cvmfs
  before_script:
    - source /cvmfs/sft.cern.ch/lcg/views/LCG_106/x86_64-el9-gcc13-opt/setup.sh
  script:
    - mkdir build && cd build
    - cmake ..
    - make -j$(nproc)
```

### Python analysis with LCG
```yaml
analysis:
  image: gitlab-registry.cern.ch/linuxsupport/alma9-base
  tags:
    - cvmfs
  before_script:
    - source /cvmfs/sft.cern.ch/lcg/views/LCG_106/x86_64-el9-gcc13-opt/setup.sh
  script:
    - python analysis.py
  artifacts:
    paths:
      - "*.pdf"
      - "*.root"
```

### Using Kerberos for EOS access in CI
```yaml
variables:
  KRB5_PRINCIPAL: "${CERN_USERNAME}@CERN.CH"
before_script:
  - echo "${KEYTAB}" | base64 -d > /tmp/krb5.keytab
  - kinit -kt /tmp/krb5.keytab ${KRB5_PRINCIPAL}
```

## Tips
- Use `tags: [cvmfs]` to get CVMFS-mounted runners
- Use CERN-provided base images from `gitlab-registry.cern.ch/linuxsupport/`
- Store credentials as CI/CD variables (Settings > CI/CD > Variables), never in the repo
- For ATLAS-specific CI, check `atlas/athena` CI templates
- Use `needs:` for parallel pipeline stages
