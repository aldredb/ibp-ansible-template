#!/bin/sh

# Usage: ./path-to-script/generate_channel_policies.sh <CHANNEL_NAME>
#
set -e

DIR=$(dirname "$0")
usage() {
	echo "usage: $0 <CHANNEL_NAME>"
}
if [ ! $# -eq 1 ]; then
	usage
	exit 1
fi

CONFIG_FILE="$DIR/../vars/channels.yaml"
ORG_CONFIG_FILE="$DIR/../vars/organizations.yaml"
CHANNEL_NAME="$1"
DEST_DIR="$DIR/../channel-policies/$CHANNEL_NAME"

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
if ! yq r -e "$CONFIG_FILE" "channels.$CHANNEL_NAME" >/dev/null; then
	echo "Invalid CHANNEL_NAME, please check your vars/channels.yaml"
	exit 1
fi

# create artifact destination folder if not exists
if [ ! -d "$DEST_DIR" ]; then
	mkdir -p "$DEST_DIR"
fi

NUM_MEMBER=$(yq r "$CONFIG_FILE" --length "channels.$CHANNEL_NAME.members")
NUM_ADMIN=$(yq r "$CONFIG_FILE" --length "channels.$CHANNEL_NAME.operators")
NUM_OUT_OF_ADMIN=$(yq r "$CONFIG_FILE" "channels.$CHANNEL_NAME.config_update_policy")

echo "Generating reader-policy.yaml for $CHANNEL_NAME"
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
for i in $(seq 0 "$(expr "$NUM_MEMBER" - 1)"); do
	org_name=$(yq r "$CONFIG_FILE" "channels.$CHANNEL_NAME".members["$i"])
	msp_id=$(yq r "$ORG_CONFIG_FILE" "peer_organizations.$org_name.msp.id")

	# update the policy file
	yq w -i "$reader_policy_file" "value.rule.n_out_of.rules[$i].signed_by" "$i"
	yq w -i "$reader_policy_file" "value.identities[$i].principal_classification" "ROLE"
	yq w -i "$reader_policy_file" "value.identities[$i].principal.msp_identifier" "$msp_id"
	yq w -i "$reader_policy_file" "value.identities[$i].principal.role" "MEMBER"
done

echo "Generating writer-policy.yaml for $CHANNEL_NAME"
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
for i in $(seq 0 "$(expr "$NUM_MEMBER" - 1)"); do
	org_name=$(yq r "$CONFIG_FILE" "channels.$CHANNEL_NAME".members["$i"])
	msp_id=$(yq r "$ORG_CONFIG_FILE" "peer_organizations.$org_name.msp.id")

	# update the policy file
	yq w -i "$writer_policy_file" "value.rule.n_out_of.rules[$i].signed_by" "$i"
	yq w -i "$writer_policy_file" "value.identities[$i].principal_classification" "ROLE"
	yq w -i "$writer_policy_file" "value.identities[$i].principal.msp_identifier" "$msp_id"
	yq w -i "$writer_policy_file" "value.identities[$i].principal.role" "MEMBER"
done

echo "Generating admin-policy.yaml for $CHANNEL_NAME"
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
	org_name=$(yq r "$CONFIG_FILE" "channels.$CHANNEL_NAME".members["$i"])
	msp_id=$(yq r "$ORG_CONFIG_FILE" "peer_organizations.$org_name.msp.id")

	# update the policy file
	yq w -i "$admin_policy_file" "value.rule.n_out_of.rules[$i].signed_by" "$i"
	yq w -i "$admin_policy_file" "value.identities[$i].principal_classification" "ROLE"
	yq w -i "$admin_policy_file" "value.identities[$i].principal.msp_identifier" "$msp_id"
	yq w -i "$admin_policy_file" "value.identities[$i].principal.role" "ADMIN"
done

# NOTE: convert all YAML file to JSON files
yq r -j -P $reader_policy_file >"$DEST_DIR/readers-policy.json"
yq r -j -P $writer_policy_file >"$DEST_DIR/writers-policy.json"
yq r -j -P $admin_policy_file >"$DEST_DIR/admins-policy.json"
