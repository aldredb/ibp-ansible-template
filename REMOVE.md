# Remove components

Here are some instructions to tear down some of the IBP components.

## Delete connection file

```sh
# ansible-playbook 09-create-connection-profile.yaml --extra-vars "peer_org_name=org1"
ansible-playbook 91-delete-connection-profile.yaml --extra-vars "peer_org_name=org1"
```

## Delete organizations (and its components)

```sh
# ansible-playbook 02-create-peer-orgs.yaml --extra-vars "org_name=org1"
ansible-playbook 98-delete-peer-orgs.yaml --extra-vars "org_name=org1"
# ansible-playbook 02-create-peer-orgs.yaml --extra-vars "org_name=org2"
ansible-playbook 98-delete-peer-orgs.yaml --extra-vars "org_name=org2"

# ansible-playbook 01-create-ordering-org.yaml --extra-vars "org_name=os"
ansible-playbook 99-delete-ordering-org.yaml --extra-vars "org_name=os"

# ansible-playbook 00-create-folders.yaml
ansible-playbook 100-delete-folders.yaml
```

## Delete IBM Blockchain Platform CRDs and console

Create a file named `uninstall-ibp.yaml` from `install-ibp.yaml.template` and fill accordingly based on the instruction found in the template (esp. `state: absent`)

```sh
cp install-crd.yaml.template uninstall-crd.yaml
cp install-ibp.yaml.template uninstall-ibp.yaml
```

Delete IBP CRDs and console by running:

```sh
# ansible-playbook install-ibp.yaml
ansible-playbook uninstall-ibp.yaml

# ansible-playbook install-crd.yaml
ansible-playbook uninstall-crd.yaml
```

## Miscellaneous

Here are some removal/deletion that were _NOT_ supported:

- uninstall chaincode
- remove peers from a channel
- delete channel

Here are some tearing-down operations that are possible, but irrelevant to our workflow:

- [remove organization from a channel](https://ibm-blockchain.github.io/ansible-collection/modules/channel_member.html)
- [remove organization from the consortium](https://ibm-blockchain.github.io/ansible-collection/modules/consortium_member.html)
