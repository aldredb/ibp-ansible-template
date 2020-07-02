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
mv vars/api.template.yaml vars/api.yaml
mv vars/organizations.template.yaml vars/organizations.yaml
mv vars/channel.template.yaml vars/channel.yaml
```

Fill in `vars/api.yaml`, `vars/organizations.yaml`, `vars/channels.yaml` with your configuration details (be careful about some data consistency requirements specified in the code comments)

### Create CA, Peers, Ordering Service, Org Def, Channel, Chaincode and all

```sh
./scripts/network.sh up

# if you only want to set up Ordering Org and Peer Org
./scripts/network.sh -b before-channel up

# if you only want to set up Ordering Org, Peer Org and channels, without joining any peers
./scripts/network.sh -b before-join up

# if you only want to set up Ordering Org, Peer Org, channels and have peers join the channel, without installing any chaincode
./scripts/network.sh -b before-chaincode up
```

> To see a detailed [step-by-step set up](./STEPWISE.md).

### Create wallet zip file to be imported to console

```sh
ansible-playbook 50-zip-identities-to-wallet.yaml
```

Import `bulk-import.zip` to IBP Console

## Cleaning up

To tear down the entire network:

```sh
./scripts/network.sh down
```
