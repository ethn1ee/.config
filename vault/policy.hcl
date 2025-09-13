path "secret/data/personal/*" {
	capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/personal/*" {
	capabilities = ["list"]
}
