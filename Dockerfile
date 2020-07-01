#
# SPDX-License-Identifier: Apache-2.0
#
# Extend from: https://github.com/IBM-Blockchain/ansible-collection/blob/master/docker/Dockerfile
# Published at: https://hub.docker.com/repository/docker/ibmapblockchain/ibp-ansible
# Maintainer: Alex Xiong <Alex.Xiong@ibm.com>

# In the first stage, install all the development packages, so we can build the native Python modules.
FROM registry.access.redhat.com/ubi8/ubi-minimal AS builder
RUN microdnf install gcc gzip python38 python38-devel tar
RUN pip3.8 install --user ansible fabric-sdk-py python-pkcs11 openshift
ENV PATH=/root/.local/bin:$PATH
ADD https://galaxy.ansible.com/api/v2/collections/ibm/blockchain_platform /root/galaxy.json
RUN ansible-galaxy collection install ibm.blockchain_platform

# In the second stage, build the Hyperledger Fabric binaries with HSM enabled (this is not the default).
FROM registry.access.redhat.com/ubi8/ubi-minimal AS fabric
RUN microdnf install git make tar gzip which findutils gcc
RUN curl -sSL https://dl.google.com/go/go1.14.4.linux-amd64.tar.gz | tar xzf - -C /usr/local
ENV GOPATH=/go
ENV PATH=/usr/local/go/bin:$PATH
RUN mkdir -p /go/src/github.com/hyperledger \
    && cd /go/src/github.com/hyperledger \
    && git clone -b v2.1.1 https://github.com/hyperledger/fabric
RUN cd /go/src/github.com/hyperledger/fabric \
    && make configtxlator peer GO_TAGS=pkcs11 EXECUTABLES=

# In the third stage, copy all the installed Python modules across from the first stage and the Hyperledger
# Fabric binaries from the second stage.
# Also install https://github.com/mikefarah/yq
FROM python:3.8-alpine
COPY --from=builder /root/.local /root/.local
COPY --from=builder /root/.ansible /root/.ansible
COPY --from=fabric /go/src/github.com/hyperledger/fabric/build/bin /opt/fabric/bin
COPY --from=fabric /go/src/github.com/hyperledger/fabric/sampleconfig /opt/fabric/config
COPY --from=fabric /go/src/github.com/hyperledger/fabric/sampleconfig /opt/fabric/config
ENV FABRIC_CFG_PATH=/opt/fabric/config
ENV PATH=/opt/fabric/bin:/root/.local/bin:$PATH
RUN apk --no-cache add curl \
    && curl -L https://github.com/mikefarah/yq/releases/download/3.3.1/yq_linux_amd64 -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq
