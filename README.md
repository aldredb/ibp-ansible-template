# Automated Deployment with Ansible

Tested on IBP Ansible Collection version: **1.0.0**

## Requirements

Before running the scripts, you need to make sure to have the following installed:

- [Ansible and IBP collection](https://ibm-blockchain.github.io/ansible-collection/installation.html#requirements). To force installation of the latest version of the collection, use `ansible-galaxy collection install --force ibm.blockchain_platform`

- YAML parser [`yq` (>= 3.4.1)](https://mikefarah.gitbook.io/yq/) - Note: Only `yq` version 3 is supported (version 4 is **NOT** supported)

- [JQ](https://stedolan.github.io/jq/download/)

- Clean up
  
  ```sh
  ansible-playbook 100-delete-folders.yaml
  ```

### Install IBM Blockchain Platform CRDs and console (Skip this section if IBP SaaS is used)

Create files from `install-crd.yaml.template`. **1** file is needed **per cluster**. Fill accordingly based on the instruction found in the template. The following example assumes that there is only 1 cluster. Create more files if needed

```sh
cp install-crd.yaml.template install-crd.yaml
```

Create files from `install-ibp.yaml.template`. **1** file is needed **per IBP instance**. Fill accordingly based on the instruction found in the template. The following example assumes that for each organization, there is a different IBP console

```sh
cp install-ibp.yaml.template install-ibp-org1.yaml
cp install-ibp.yaml.template install-ibp-org2.yaml
cp install-ibp.yaml.template install-ibp-org3.yaml
```

Log in to your Openshift/Kubernetes Cluster and ensure that you can interact with the cluster. Install IBP CRDs and Console by issuing the command below. If the CRDs and Console are located in different clusters, ensure that you logged in to the respective clusters before issuing the commands.

```sh
ansible-playbook install-crd.yaml
ansible-playbook install-ibp-org1.yaml
ansible-playbook install-ibp-org2.yaml
ansible-playbook install-ibp-org3.yaml
```

Open your IBP console(s) in your browser and change your initial default password to log in.

### Prepare files

Copy the organizations template file. Modify the YAML file as needed (be careful about some data consistency requirements specified in the code comments)

```sh
cp vars/organizations.template.yaml vars/organizations.yaml
```

Copy the channels template file. Modify the YAML file as needed (be careful about some data consistency requirements specified in the code comments)

```sh
cp vars/channels.template.yaml vars/channels.yaml
```

### Create Folders

Create folders to store wallet, connection profiles and configuration

```sh
ansible-playbook 00-create-folders.yaml
```

### Create organizations

```sh
ansible-playbook 01-create-ordering-org.yaml --extra-vars "org_name=os" -v

ansible-playbook 02-create-peer-orgs.yaml --extra-vars "org_name=org1" -v
ansible-playbook 02-create-peer-orgs.yaml --extra-vars "org_name=org2" -v
ansible-playbook 02-create-peer-orgs.yaml --extra-vars "org_name=org3" -v
```

### Import Components

As the organizations are hosted in different IBP instances, import the MSP definitions and orderers to all the consoles. If the organizations are hosted in the same IBP instance, skip this section

```sh
ansible-playbook 03-import-components.yaml -v
```

### Add organizations to Consortium and create channel

Add organizations to consortium

```sh
ansible-playbook 04-add-orgs-to-consortium.yaml --extra-vars "os_org_name=os" -v
```

Create `common-channel`

```sh
./scripts/generate_channel_policies.sh common-channel
ansible-playbook 05-create-channel.yaml --extra-vars "channel_name=common-channel os_org_name=os creator_org_name=org1" -v
```

Create `org1-org2-channel`

```sh
./scripts/generate_channel_policies.sh org1-org2-channel
ansible-playbook 05-create-channel.yaml --extra-vars "channel_name=org1-org2-channel os_org_name=os creator_org_name=org1" -v
```

### Join peers to channel and add anchor peers

Join peers to `common-channel`

```sh
ansible-playbook 06-join-peers-to-channel.yaml --extra-vars "channel_name=common-channel os_org_name=os peer_org_name=org1" -v
ansible-playbook 06-join-peers-to-channel.yaml --extra-vars "channel_name=common-channel os_org_name=os peer_org_name=org2" -v
ansible-playbook 06-join-peers-to-channel.yaml --extra-vars "channel_name=common-channel os_org_name=os peer_org_name=org3" -v
```

Add anchor peers for `common-channel`

```sh
ansible-playbook 07-add-anchor-peer-to-channel.yaml --extra-vars "channel_name=common-channel os_org_name=os peer_org_name=org1" -v
ansible-playbook 07-add-anchor-peer-to-channel.yaml --extra-vars "channel_name=common-channel os_org_name=os peer_org_name=org2" -v
ansible-playbook 07-add-anchor-peer-to-channel.yaml --extra-vars "channel_name=common-channel os_org_name=os peer_org_name=org3" -v
```

Join peers to `org1-org2-channel`

```sh
ansible-playbook 06-join-peers-to-channel.yaml --extra-vars "channel_name=org1-org2-channel os_org_name=os peer_org_name=org1" -v
ansible-playbook 06-join-peers-to-channel.yaml --extra-vars "channel_name=org1-org2-channel os_org_name=os peer_org_name=org2" -v
```

Add anchor peers for `org1-org2-channel`

```sh
ansible-playbook 07-add-anchor-peer-to-channel.yaml --extra-vars "channel_name=org1-org2-channel os_org_name=os peer_org_name=org1" -v
ansible-playbook 07-add-anchor-peer-to-channel.yaml --extra-vars "channel_name=org1-org2-channel os_org_name=os peer_org_name=org2" -v
```

### Utility functions

Create connection profile

```sh
ansible-playbook 10-create-connection-profile.yaml --extra-vars "peer_org_name=org1"
ansible-playbook 10-create-connection-profile.yaml --extra-vars "peer_org_name=org2"
ansible-playbook 10-create-connection-profile.yaml --extra-vars "peer_org_name=org3"
```

Create wallet zip file to be imported to console

```sh
ansible-playbook 50-zip-identities-to-wallet.yaml
```

Import `bulk-import.zip` to IBP Console

### Automation Script

```sh
./scripts/network.sh up

# if you only want to set up Ordering Org and Peer Org
./scripts/network.sh -b before-channel up

# if you only want to set up Ordering Org, Peer Org and channels, without joining any peers
./scripts/network.sh -b before-join up
```

## Cleaning up

Refer to [REMOVE.md](./REMOVE.md)
