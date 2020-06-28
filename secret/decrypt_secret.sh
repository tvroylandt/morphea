#!/bin/sh

# Decrypt the file
mkdir $HOME/secret
# --batch to prevent interactive command
# --yes to assume "yes" for questions
gpg --quiet --batch --yes --decrypt --passphrase="$LARGE_SECRET_PASSPHRASE" \
--output $HOME/secret/morphea_token.json morphea_token.gpg