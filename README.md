# Automated Deployment with Ansible

This folder contains ansible scripts, configs to setup a blockchain network on IBP deployed on Openshift in an automated manner, thanks to [IBM ansible collection](https://github.com/IBM-Blockchain/ansible-collection).

## Requirements

Before running the scripts, you need to make sure to have all [required software](https://ibm-blockchain.github.io/ansible-collection/installation.html#requirements) installed

## Getting Started

Log in to your Openshift/Kubernetes Cluster, verify by running:

```sh
$ kubectl get nodes
NAME            STATUS   ROLES           AGE     VERSION
10.192.254.90   Ready    master,worker   3d21h   v1.16.2
10.193.88.253   Ready    master,worker   3d20h   v1.16.2
10.212.54.221   Ready    master,worker   3d21h   v1.16.2
```

### Install IBM Blockchain Platform

Note: Skip this section if IBP SaaS is used

Create a file named `install-ibp.yaml` from `install-ibp.yaml.template`

```sh
cp install-ibp.yaml.template install-ibp.yaml
```

Change the following variables:

- Replace `<project>` with the name of the Red Hat OpenShift project, that you are installing the IBM Blockchain Platform into.
- Replace `<image_registry_password>` with your IBM Blockchain Platform entitlement key([link](https://myibm.ibm.com/products-services/containerlibrary)).
- Replace `<image_registry_email>` with the email address of your IBMid account that you use to access the My IBM dashboard.
- Replace `<console_domain>` with the domain name of your Kubernetes cluster or Red Hat OpenShift cluster. This domain name is used as the base domain name for all ingress or routes created by the IBM Blockchain Platform.
- Replace `<console_email>` with the email address of the IBM Blockchain Platform console user that will be created during the installation process. You will use this email address to access the IBM Blockchain Platform console after installation.
- Replace `<console_default_password>` with the default password for the IBM Blockchain Platform console. This default password will be set as the password for all new users, including the user created during the installation process.
- By default, the `<wait_timeout>` variable is set to 3600 seconds (1 hour), which should be sufficient for most environments. You only need to change the value for this variable if you find that timeout errors occur during the installation process.

> NOTE: if your Openshift Cluster is on multizones: add the following to `install-ibp.yaml`:

```yaml
clusterdata:
  zones:
    - <zone_1>
    - <zone_2>
```

Install the IBP by running:

```sh
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
cp api.yaml.template vars/api.yaml
```

Fill in `vars/api.yaml`

### Create organizations

```sh
ansible-playbook 01-create-ordering-org.yaml --extra-vars "org_name=os"

ansible-playbook 02-create-peer-orgs.yaml --extra-vars "org_name=org1"
ansible-playbook 02-create-peer-orgs.yaml --extra-vars "org_name=org2"
```

### Create channel and join peers to channel

```sh
ansible-playbook 03-add-org-to-consortium.yaml --extra-vars "os_org_name=os"

ansible-playbook 04-create-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os creator_org_name=org1" -v

ansible-playbook 05-join-peers-to-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os peer_org_name=org1" -v
ansible-playbook 05-join-peers-to-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os peer_org_name=org2" -v
```

### Create wallet zip file to be imported to console

```sh
ansible-playbook 99-zip-identities-to-wallet.yaml
```

Import `Wallet.zip` to IBP Console
