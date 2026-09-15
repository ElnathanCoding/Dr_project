# Security

Do not commit patient information, research datasets, credentials, Android
signing material, private keys, or machine-local environment files.

The public repository intentionally excludes `key.properties`, keystores,
`.env` files containing real credentials, local SDK configuration, datasets,
locked-test images, generated logs, and packaged Windows runtime DLLs.

`Website/.env.example` is a configuration template and does not contain the
project's real environment credentials.

If a real credential is exposed, rotate or revoke it immediately and evaluate
whether Git history must be rewritten.
