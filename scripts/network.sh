#!/usr/bin/env bash
#
# Setup IBP network and all components

set -euo pipefail

ACTION=
OPT_BEFORE_CHANNEL=false
OPT_BEFORE_JOIN=false

function usage() {
	echo "usage: $0 [OPTIONS] [up|down]" 1>&2
	echo
	echo "[OPTIONS]"
	echo "-h                    help message"
	echo "-b  [BREAKPOINT]      Setup until a breakpoint"
	echo "    before-channel    Setup until channel creation (all ordering, peer orgs created)"
	echo "    before-join       Setup until peer join channel (all ordering, peer orgs, channel created)"
}

function cmd_exists() {
	if [ ! $# -eq 1 ]; then
		echo "usage: $(basename "$0") command"
	fi
	command -v "$1" >/dev/null 2>&1
}

function check_dep() {
	for tool in ansible-galaxy ansible-playbook yq; do
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

function set_org_vars() {
  PEER_ORG_ARRAY=($(echo $(yq r vars/organizations.yaml "peer_organizations" | yq r - --printMode p "*") | tr "\n" "\n"))
  ORDERER_ORG_ARRAY=($(echo $(yq r vars/organizations.yaml "ordering_organization" | yq r - --printMode p "*") | tr "\n" "\n"))
  CHANNEL_ARRAY=($(echo $(yq r vars/channels.yaml "channels" | yq r - --printMode p "*") | tr "\n" "\n"))
  CONSORTIUM_MEMBERS_ARRAY=($(echo $(yq r vars/channels.yaml "consortium_members.*") | tr "\n" "\n"))

  if [ ${#CONSORTIUM_MEMBERS_ARRAY} -lt 1 ]; then
    echo "There are no consortium members"
    exit 1
  fi

  # Assume the first orderer organization
  if [ ${#ORDERER_ORG_ARRAY} -gt 0 ]; then
    ORDERER_ORG=${ORDERER_ORG_ARRAY[0]}
  else
    echo "There are no ordering organizations"
    exit 1
  fi

	for ch in "${CHANNEL_ARRAY[@]}"; do
    CHANNEL_MEMBERS_ARRAY=($(echo $(yq r vars/channels.yaml "channels[$ch].members" | yq r - --printMode p "*") | tr "\n" "\n"))
    INTERSECT=()
    for channel_member in "${CHANNEL_MEMBERS_ARRAY[@]}"; do
        for consortium_member in "${CONSORTIUM_MEMBERS_ARRAY[@]}"; do
            if [[ $channel_member = $consortium_member ]]; then
                INTERSECT+=("$channel_member")
            fi
        done
    done
    if [ ${#INTERSECT} -lt 1 ]; then
      echo "There are no channel members for $ch that belong to the consortium"
      exit 1
    fi
    CREATOR_ORG=${INTERSECT[0]}
    echo "Creator Org for $ch - $CREATOR_ORG"
  done
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

printf "%s\n" "🔍 Listing organizations, channels and consortium members ... "
set_org_vars

echo ""
echo "Consortium Members:"
for member in "${CONSORTIUM_MEMBERS_ARRAY[@]}"; do
    echo "$member"
done

echo "" 
echo "Peer Organizations:"
for i in "${PEER_ORG_ARRAY[@]}"; do
  echo $i
done

echo "" 
echo "Ordering Organizations:"
for i in "${ORDERER_ORG_ARRAY[@]}"; do
  echo $i
done

echo ""
echo "Channels:"
for i in "${CHANNEL_ARRAY[@]}"; do
  echo $i
done

echo ""
echo "Orderer Organization: $ORDERER_ORG"
echo "done"

case "$ACTION" in
up)

	echo "🚀 Setting up your IBP Platform ... "
	ansible-playbook 00-create-folders.yaml

	for org in "${ORDERER_ORG_ARRAY[@]}"; do
  	ansible-playbook 01-create-ordering-org.yaml --extra-vars "org_name=$org" -v
	done

	for org in "${PEER_ORG_ARRAY[@]}"; do
  	ansible-playbook 02-create-peer-orgs.yaml --extra-vars "org_name=$org" -v
	done

	ansible-playbook 03-import-components.yaml -v

	if "$OPT_BEFORE_CHANNEL"; then
		success_exit
	fi

	ansible-playbook 04-add-orgs-to-consortium.yaml --extra-vars "os_org_name=$ORDERER_ORG" -v

	for ch in "${CHANNEL_ARRAY[@]}"; do
  	CHANNEL_MEMBERS_ARRAY=($(echo $(yq r vars/channels.yaml "channels[$ch].members" | yq r - --printMode p "*") | tr "\n" "\n"))
  
		INTERSECTION=()

		for channel_member in "${CHANNEL_MEMBERS_ARRAY[@]}"; do
				for consortium_member in "${CONSORTIUM_MEMBERS_ARRAY[@]}"; do
						if [[ $channel_member = $consortium_member ]]; then
								INTERSECTION+=("$channel_member")
						fi
				done
		done

  	CREATOR_ORG=${INTERSECTION[0]}
		echo "Creator Org for $ch - $CREATOR_ORG"

		./scripts/generate_channel_policies.sh $ch

		ansible-playbook 05-create-channel.yaml \
			--extra-vars "channel_name=$ch os_org_name=$ORDERER_ORG creator_org_name=$CREATOR_ORG" -v
	done

	if "$OPT_BEFORE_JOIN"; then
		success_exit
	fi

	for ch in "${CHANNEL_ARRAY[@]}"; do
    # Retrieve channel members for the channel
    CHANNEL_MEMBERS=$(yq r vars/channels.yaml "channels[$ch].members" | yq r - --printMode p "*")
  	for channel_member in $CHANNEL_MEMBERS; do

			echo "Joining peers from organization: $channel_member to channel: $ch"
      ansible-playbook 06-join-peers-to-channel.yaml \
				--extra-vars "channel_name=$ch os_org_name=$ORDERER_ORG peer_org_name=$channel_member" -v

			echo "Adding anchor peers from organization: $channel_member to channel: $ch"
			ansible-playbook 07-add-anchor-peer-to-channel.yaml \
				--extra-vars "channel_name=$ch os_org_name=$ORDERER_ORG peer_org_name=$channel_member" -v
    done
	done

	success_exit
	;;
down)
	echo "🧹 Tearing down ... "
	ansible-playbook 97-remove-imported-components.yaml

	for org in "${PEER_ORG_ARRAY[@]}"; do
  	ansible-playbook 98-delete-peer-orgs.yaml --extra-vars "org_name=$org" -v
	done

	for org in "${ORDERER_ORG_ARRAY[@]}"; do
  	ansible-playbook 99-delete-ordering-org.yaml --extra-vars "org_name=$org" -v
	done

	ansible-playbook 100-delete-folders.yaml
	success_exit
	;;
*)
	usage
	exit 1
	;;
esac
