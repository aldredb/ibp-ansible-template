# Automated Deployment with Ansible

This folder contains ansible scripts, configs to setup a blockchain network on IBP deployed on Openshift in an automated manner, thanks to [IBM ansible collection](https://github.com/IBM-Blockchain/ansible-collection).

Tested on IBP Ansible Collection version: **0.0.30**

## Requirements

Before running the scripts, you need to make sure to have the following installed:

- [Ansible and IBP collection](https://ibm-blockchain.github.io/ansible-collection/installation.html#requirements)

- YAML parser [`yq` (>= 3.3.2)](https://mikefarah.gitbook.io/yq/)

## Getting Started

Log in to your Openshift/Kubernetes Cluster, verify by running:

```sh
$ kubectl get nodes
NAME            STATUS   ROLES           AGE     VERSION
10.192.254.90   Ready    master,worker   3d21h   v1.16.2
10.193.88.253   Ready    master,worker   3d20h   v1.16.2
10.212.54.221   Ready    master,worker   3d21h   v1.16.2
```

### Install IBM Blockchain Platform CRDs and console

Note: Skip this section if IBP SaaS is used

Create a file named `install-ibp.yaml` from `install-ibp.yaml.template` and fill accordingly based on the instruction found in the template

```sh
cp install-crd.yaml.template install-crd.yaml
cp install-ibp.yaml.template install-ibp.yaml
```

Install IBP CRDs and console by running:

```sh
$ ansible-playbook install-crd.yaml
$ ansible-playbook install-ibp.yaml

…
TASK [console : Print console URL] *********
ok: [localhost] => {
    "msg": "IBM Blockchain Platform console available at https://<PROJECT_NAME>-ibp-console-console.<DOMAIN>"
}
…
PLAY RECAP *********************************
localhost: ok=20   changed=7    unreachable=0    failed=0    skipped=13   rescued=0    ignored=0
```

Now you could open your IBP console in your browser and change your initial default password to log in.

### Create api variable file

```sh
cp vars/api.yaml.template vars/api.yaml
```

Fill in `vars/api.yaml`

### Create organizations

```sh
ansible-playbook 00-create-folders.yaml

ansible-playbook 01-create-ordering-org.yaml --extra-vars "org_name=os"

ansible-playbook 02-create-peer-orgs.yaml --extra-vars "org_name=org1"
ansible-playbook 02-create-peer-orgs.yaml --extra-vars "org_name=org2"
```

### Create channel and join peers to channel

```sh
ansible-playbook 03-add-org-to-consortium.yaml --extra-vars "os_org_name=os"

./scripts/generate_channel_policies.sh samplechannel1
ansible-playbook 04-create-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os creator_org_name=org1" -v
./scripts/generate_channel_policies.sh samplechannel2
ansible-playbook 04-create-channel.yaml --extra-vars "channel_name=samplechannel2 os_org_name=os creator_org_name=org1" -v

ansible-playbook 05-join-peers-to-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os peer_org_name=org1" -v
ansible-playbook 05-join-peers-to-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os peer_org_name=org2" -v

ansible-playbook 05-join-peers-to-channel.yaml --extra-vars "channel_name=samplechannel2 os_org_name=os peer_org_name=org1" -v

ansible-playbook 06-add-anchor-peer-to-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os peer_org_name=org1" -v
ansible-playbook 06-add-anchor-peer-to-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os peer_org_name=org2" -v
```

### Install and instantiate chaincode

```sh
ansible-playbook 07-install-chaincode.yaml --extra-vars "peer_org_name=org1 cc_path=chaincode/marbles@v2.cds"
ansible-playbook 07-install-chaincode.yaml --extra-vars "peer_org_name=org2 cc_path=chaincode/marbles@v2.cds"

ansible-playbook 08-instantiate-chaincode.yaml --extra-vars "peer_org_name=org1 channel_name=samplechannel1 cc_name=marbles"
```

### Create connection profile

```sh
ansible-playbook 09-create-connection-profile.yaml --extra-vars "peer_org_name=org1"
```

### Create wallet zip file to be imported to console

```sh
ansible-playbook 50-zip-identities-to-wallet.yaml
```

Import `bulk-import.zip` to IBP Console
