#!/usr/bin/env bash
#
# Setup IBP network and all components

set -euo pipefail

ACTION=
OPT_BEFORE_CHANNEL=false
OPT_BEFORE_JOIN=false
OPT_BEFORE_CHAINCODE=false
OPT_ONLY_PEER_ORGS=false
OPT_ONLY_ORDERING=false

function usage() {
	echo "usage: $0 [OPTIONS] [up|down]" 1>&2
	echo
	echo "[OPTIONS]"
	echo "-h                    help message"
	echo "-b  [BREAKPOINT]      Setup/Teardown until a breakpoint"
	echo "    before-channel    Setup until channel creation (all ordering, peer orgs created)"
	echo "    before-join       Setup until peer join channel (all ordering, peer orgs, channel created)"
	echo "    before-chaincode  Setup until chaincode installation"
	echo
	echo "    only-peer-orgs    Delete only peer orgs"
	echo "    only-ordering     Delete only ordering orgs"
}

function cmd_exists() {
	if [ ! $# -eq 1 ]; then
		echo "usage: $(basename "$0") command"
	fi
	command -v "$1" >/dev/null 2>&1
}

function check_dep() {
	for tool in ansible-galaxy ansible-playbook; do
		if ! cmd_exists $tool; then
			echo "⚠ Please install: $tool !"
			exit 1
		fi
	done

}

function success_exit() {
	echo "done"
	exit 0
}

while getopts ":hb:" opt; do
	case "${opt}" in
	h)
		usage
		exit 0
		;;
	b)
		case "$OPTARG" in
		before-channel)
			OPT_BEFORE_CHANNEL=true
			;;
		before-join)
			OPT_BEFORE_JOIN=true
			;;
		before-chaincode)
			OPT_BEFORE_CHAINCODE=true
			;;
		only-peer-orgs)
			OPT_ONLY_PEER_ORGS=true
			;;
		only-ordering)
			OPT_ONLY_ORDERING=true
			;;
		\?)
			echo "Invalid FLAGS: --$OPTARG" 1>&2
			usage
			exit 1
			;;
		esac
		;;
	\?)
		usage
		exit 1
		;;
	esac
done
shift $((OPTIND - 1))
if [ "$#" != 1 ]; then
	usage
	exit 1
else
	ACTION=$1
fi

printf "%s" "🔍 Checking required tools ... "
check_dep
echo "done"

# update to ansible-collection to the latest
ansible-galaxy collection install ibm.blockchain_platform -f

case "$ACTION" in
up)
	printf "%s" "🚀 Setting up your IBP Platform ... "
	ansible-playbook 00-create-folders.yaml
	ansible-playbook 01-create-ordering-org.yaml --extra-vars "org_name=os"
	ansible-playbook 02-create-peer-orgs.yaml --extra-vars "org_name=org1"
	ansible-playbook 02-create-peer-orgs.yaml --extra-vars "org_name=org2"

	if "$OPT_BEFORE_CHANNEL"; then
		success_exit
	fi

	ansible-playbook 03-add-org-to-consortium.yaml --extra-vars "os_org_name=os"
	./scripts/generate_channel_policies.sh samplechannel1
	ansible-playbook 04-create-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os creator_org_name=org1" -v
	./scripts/generate_channel_policies.sh samplechannel2
	ansible-playbook 04-create-channel.yaml --extra-vars "channel_name=samplechannel2 os_org_name=os creator_org_name=org1" -v

	if "$OPT_BEFORE_JOIN"; then
		success_exit
	fi

	ansible-playbook 05-join-peers-to-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os peer_org_name=org1" -v
	ansible-playbook 05-join-peers-to-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os peer_org_name=org2" -v
	ansible-playbook 05-join-peers-to-channel.yaml --extra-vars "channel_name=samplechannel2 os_org_name=os peer_org_name=org1" -v
	ansible-playbook 06-add-anchor-peer-to-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os peer_org_name=org1" -v
	ansible-playbook 06-add-anchor-peer-to-channel.yaml --extra-vars "channel_name=samplechannel1 os_org_name=os peer_org_name=org2" -v

	if "$OPT_BEFORE_CHAINCODE"; then
		success_exit
	fi
	ansible-playbook 07-install-chaincode.yaml --extra-vars "peer_org_name=org1 cc_path=chaincode/marbles@v2.cds"
	ansible-playbook 07-install-chaincode.yaml --extra-vars "peer_org_name=org2 cc_path=chaincode/marbles@v2.cds"
	ansible-playbook 08-instantiate-chaincode.yaml --extra-vars "peer_org_name=org1 channel_name=samplechannel1 cc_name=marbles"
	success_exit
	;;
down)
	printf "%s" "🧹 Tearing down ... "
	ansible-playbook 91-delete-connection-profile.yaml --extra-vars "peer_org_name=org1"
	if ! "$OPT_ONLY_PEER_ORGS"; then
		ansible-playbook 98-delete-peer-orgs.yaml --extra-vars "org_name=org1"
		ansible-playbook 98-delete-peer-orgs.yaml --extra-vars "org_name=org2"
		success_exit
	fi
	if ! "$OPT_ONLY_ORDERING"; then
		ansible-playbook 99-delete-ordering-org.yaml --extra-vars "org_name=os"
		success_exit
	fi

	ansible-playbook 100-delete-folders.yaml
	success_exit
	;;
*)
	usage
	exit 1
	;;
esac
