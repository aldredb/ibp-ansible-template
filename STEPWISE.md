# Step by Step IBP Components Setup

Assuming you have set up your IBP and finish specifying your `vars/*.yaml` configurations.

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
