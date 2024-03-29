#!/usr/bin/env bash
#
# Usage: ./path-to-script/generate_channel_policies.sh <CHANNEL_NAME>
#

set -euo pipefail

DIR=$(dirname $(dirname "$0"))
usage() {
	echo "usage: $0 <CHANNEL_NAME>"
}
if [ ! $# -eq 1 ]; then
	usage
	exit 1
fi

CONFIG_FILE="$DIR/vars/channels.yaml"
ORG_CONFIG_FILE="$DIR/vars/organizations.yaml"
CHANNEL_NAME="$1"
DEST_DIR="$DIR/channel-policies/$CHANNEL_NAME"

# check the channel config file exists
if [ ! -f "$CONFIG_FILE" ] || [ ! -f "$ORG_CONFIG_FILE" ]; then
	echo "Config file not found: vars/channels.yaml and/or vars/organizations.yaml !"
	exit 1
fi

# check yq command exist
if ! [ -x "$(command -v yq)" ]; then
	echo 'Error: yq is not installed.' >&2
	exit 1
fi

# check CHANNEL_NAME exists in config file
if [ -z "$(yq r "$CONFIG_FILE" "channels.$CHANNEL_NAME")" ]; then
	echo "Invalid CHANNEL_NAME: $CHANNEL_NAME, please check your vars/channels.yaml"
	exit 1
fi

# create artifact destination folder if not exists
if [ ! -d "$DEST_DIR" ]; then
	mkdir -p "$DEST_DIR"
fi

MEMBER_ORGS=$(yq r "$CONFIG_FILE" --printMode p "channels.$CHANNEL_NAME.members.*" | awk -F "." '{print $4}')
NUM_WRITER=$(yq r "$CONFIG_FILE" --length "channels.$CHANNEL_NAME.writers")
NUM_ADMIN=$(yq r "$CONFIG_FILE" --length "channels.$CHANNEL_NAME.operators")
NUM_DEFAULT_CC_ENDORSER=$(yq r "$CONFIG_FILE" --length "channels.$CHANNEL_NAME.default_chaincode_endorsers")
NUM_CC_LIFECYCLE=$(yq r "$CONFIG_FILE" --length "channels.$CHANNEL_NAME.chaincode_lifecycle")
NUM_OUT_OF_ADMIN=$(yq r "$CONFIG_FILE" "channels.$CHANNEL_NAME.config_update_policy")

echo "Generating readers-policy.yaml for $CHANNEL_NAME"
reader_policy_file="$DEST_DIR/readers-policy.yaml"
cat <<EOT >"$reader_policy_file"
type: 1
value:
  rule:
    n_out_of:
      n: 1
      rules:
  identities:
EOT
i=0
for org_name in $MEMBER_ORGS; do
	msp_id=$(yq r "$ORG_CONFIG_FILE" "peer_organizations.$org_name.msp.id")

	# update the policy file
	yq w -i "$reader_policy_file" "value.rule.n_out_of.rules[$i].signed_by" "$i"
	yq w -i "$reader_policy_file" "value.identities[$i].principal_classification" "ROLE"
	yq w -i "$reader_policy_file" "value.identities[$i].principal.msp_identifier" "$msp_id"
	yq w -i "$reader_policy_file" "value.identities[$i].principal.role" "MEMBER"
	i=$(expr $i + 1)
done

echo "Generating writers-policy.yaml for $CHANNEL_NAME"
writer_policy_file="$DEST_DIR/writers-policy.yaml"
cat <<EOT >"$writer_policy_file"
type: 1
value:
  rule:
    n_out_of:
      n: 1
      rules:
  identities:
EOT
for i in $(seq 0 "$(expr "$NUM_WRITER" - 1)"); do
	org_name=$(yq r "$CONFIG_FILE" "channels.$CHANNEL_NAME".writers["$i"])
	msp_id=$(yq r "$ORG_CONFIG_FILE" "peer_organizations.$org_name.msp.id")

	# update the policy file
	yq w -i "$writer_policy_file" "value.rule.n_out_of.rules[$i].signed_by" "$i"
	yq w -i "$writer_policy_file" "value.identities[$i].principal_classification" "ROLE"
	yq w -i "$writer_policy_file" "value.identities[$i].principal.msp_identifier" "$msp_id"
	yq w -i "$writer_policy_file" "value.identities[$i].principal.role" "MEMBER"
done

echo "Generating admins-policy.yaml for $CHANNEL_NAME"
admin_policy_file="$DEST_DIR/admins-policy.yaml"
cat <<EOT >"$admin_policy_file"
type: 1
value:
  rule:
    n_out_of:
      n: 0
      rules:
  identities:
EOT
yq w -i "$admin_policy_file" "value.rule.n_out_of.n" "$NUM_OUT_OF_ADMIN"
for i in $(seq 0 "$(expr "$NUM_ADMIN" - 1)"); do
	org_name=$(yq r "$CONFIG_FILE" "channels.$CHANNEL_NAME".operators["$i"])
	msp_id=$(yq r "$ORG_CONFIG_FILE" "peer_organizations.$org_name.msp.id")

	# update the policy file
	yq w -i "$admin_policy_file" "value.rule.n_out_of.rules[$i].signed_by" "$i"
	yq w -i "$admin_policy_file" "value.identities[$i].principal_classification" "ROLE"
	yq w -i "$admin_policy_file" "value.identities[$i].principal.msp_identifier" "$msp_id"
	yq w -i "$admin_policy_file" "value.identities[$i].principal.role" "ADMIN"
done

echo "Generating default-cc-endorsers.yaml for $CHANNEL_NAME"
default_cc_endorsers_file="$DEST_DIR/default-cc-endorsers.yaml"
cat <<EOT >"$default_cc_endorsers_file"
type: 1
value:
  rule:
    n_out_of:
      n: 1
      rules:
  identities:
EOT
for i in $(seq 0 "$(expr "$NUM_DEFAULT_CC_ENDORSER" - 1)"); do
	org_name=$(yq r "$CONFIG_FILE" "channels.$CHANNEL_NAME".default_chaincode_endorsers["$i"])
	msp_id=$(yq r "$ORG_CONFIG_FILE" "peer_organizations.$org_name.msp.id")

	# update the policy file
	yq w -i "$default_cc_endorsers_file" "value.rule.n_out_of.rules[$i].signed_by" "$i"
	yq w -i "$default_cc_endorsers_file" "value.identities[$i].principal_classification" "ROLE"
	yq w -i "$default_cc_endorsers_file" "value.identities[$i].principal.msp_identifier" "$msp_id"
	yq w -i "$default_cc_endorsers_file" "value.identities[$i].principal.role" "MEMBER"
done

echo "Generating cc-lifecycle.yaml for $CHANNEL_NAME"
cc_lifecycle_file="$DEST_DIR/cc-lifecycle.yaml"
cat <<EOT >"$cc_lifecycle_file"
type: 1
value:
  rule:
    n_out_of:
      n: 1
      rules:
  identities:
EOT
for i in $(seq 0 "$(expr "$NUM_CC_LIFECYCLE" - 1)"); do
	org_name=$(yq r "$CONFIG_FILE" "channels.$CHANNEL_NAME".chaincode_lifecycle["$i"])
	msp_id=$(yq r "$ORG_CONFIG_FILE" "peer_organizations.$org_name.msp.id")

	# update the policy file
	yq w -i "$cc_lifecycle_file" "value.rule.n_out_of.rules[$i].signed_by" "$i"
	yq w -i "$cc_lifecycle_file" "value.identities[$i].principal_classification" "ROLE"
	yq w -i "$cc_lifecycle_file" "value.identities[$i].principal.msp_identifier" "$msp_id"
	yq w -i "$cc_lifecycle_file" "value.identities[$i].principal.role" "MEMBER"
done

# NOTE: convert all YAML file to JSON files
# yq r -j -P $reader_policy_file >"$DEST_DIR/readers-policy.json"
# yq r -j -P $writer_policy_file >"$DEST_DIR/writers-policy.json"
# yq r -j -P $admin_policy_file >"$DEST_DIR/admins-policy.json"
