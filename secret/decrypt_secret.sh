# Encryption of the token
# see https://help.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets

# gpg --symmetric --cipher-algo AES256 ./secret/morphea_token.json
# --batch to prevent interactive command
# --yes to assume "yes" for questions
gpg --quiet --batch --yes --decrypt --passphrase="$LARGE_SECRET_PASSPHRASE" \
--output ./secret/morphea_token.json ./secret/morphea_token.json.gpg