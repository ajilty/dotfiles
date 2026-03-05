#!/bin/bash
# whoami: Context and environment information utilities
#
# Functions:
#   whoami-aws     - Display current AWS identity and configuration
#   whoami-python  - Display Python environment information

# helpful AWS context. get get-caller-identity, resolve account ID to account alias, print this all out
whoami-aws() {
    caller_identity=$(aws sts get-caller-identity --output json --no-cli-pager)
    account_id=$(echo $caller_identity | jq -r '.Account')
    account_alias=$(aws iam list-account-aliases --output json | jq -r '.AccountAliases[0]')
    echo "[Current Identity]"
    echo "Account Alias: $account_alias"
    aws sts get-caller-identity --output yaml --no-cli-pager

    echo "\n[Configuration]"
    aws configure list  --output table

    echo "\n[Profiles]"
    aws configure list-profiles  --output table

    echo "\nNew:"
    echo " - To establish a *new* SSO session, run \`aws configure sso-session\`"
    echo " - To add a *new* profile with the SSO session, run \`aws configure sso\`, then set the profile name"

    echo "\nExisting:"
    echo " - To refresh an existing SSO session, run \`aws sso login\`"
    echo " - To use the an existing profile, run \`export AWS_PROFILE=<profile_name>\`"
}

whoami-python() {
    echo "Python Version: $(python --version)"
    echo "Python Location: $(which python)"
    echo "Python Virtual Environment: $VIRTUAL_ENV"
    echo "Python Path: $PYTHONPATH"
    echo "Python Packages: $(pip list)"
}
