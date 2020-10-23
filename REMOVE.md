# Remove Components

Here are some instructions to tear down some of the IBP components.

## Delete organizations (and its components)

```sh
ansible-playbook 97-remove-imported-components.yaml
ansible-playbook 98-delete-peer-orgs.yaml --extra-vars "org_name=org1"
ansible-playbook 98-delete-peer-orgs.yaml --extra-vars "org_name=org2"
ansible-playbook 98-delete-peer-orgs.yaml --extra-vars "org_name=org3"

ansible-playbook 99-delete-ordering-org.yaml --extra-vars "org_name=os"

ansible-playbook 100-delete-folders.yaml
```

## Automation Script

```sh
./scripts/network.sh down
```

## Delete IBM Blockchain Platform CRDs and console

Create a file named `uninstall-ibp.yaml` from `install-ibp.yaml.template` and fill accordingly based on the instruction found in the template (esp. `state: absent`)

```sh
cp install-crd.yaml.template uninstall-crd.yaml
cp install-ibp.yaml.template uninstall-ibp-org1.yaml
cp install-ibp.yaml.template uninstall-ibp-org2.yaml
cp install-ibp.yaml.template uninstall-ibp-org3.yaml
```

Delete IBP CRDs and console by running:

```sh
ansible-playbook uninstall-ibp-org1.yaml
ansible-playbook uninstall-ibp-org2.yaml
ansible-playbook uninstall-ibp-org3.yaml

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
