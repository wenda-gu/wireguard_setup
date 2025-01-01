# WireGuard Setup Scripts
For Mac client and ubuntu 24.04 LTS server on Linode.

- Run `chmod +x filename` to grant execution permission to a file.
- Run `./1_setup_wireguard_server.sh` to set up the server.
- Run `./2_add_client.sh` to add a client to the server and download the configuration file to the Desktop of the local machine for tunnel import.
- Run `./3_delete_host_entry.sh` to delete SSH configurations for the server on the local machine.

- `wireguard-init.yaml` for cloud init, but not finished yet.

