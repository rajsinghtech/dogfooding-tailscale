# ts-acl-sync
Sync Tailscale ACL files to Tailnets
=======
# Tailscale ACL Sync

## Disclaimer

> [!WARNING]
> This repo is intended to be used for educational purposes only. This is just a starting point to get up and running as a proof-of-concept. Please do not attempt to use this for a production setup or anything serious as I won't be responsible or provide support. You are responsible for backing up your ACL files. Honestly, this repo doesn't need to exist and you shouldn't use it.

## Description

This is a very primitive repo that uses the Tailscale Terraform provider to sync a `json` or `jujson` ACL file from your filesystem to your tailnet of choice based on Oauth client credentials you supply.

## How to Use

1. [Setup an Oauth client](https://tailscale.com/kb/1215/oauth-clients#setting-up-an-oauth-client) and enable the `Write` checkbox to `Policy File` in your tailnet admin panel. Make a note of your client ID and client secret values
2. Copy `terraform.tfvars.example` to `terraform.tfvars`
3. Edit the values in `terraform.tfvars` as needed. Make sure you have a valid `json` or `hujson` formatted file + path defined. Feel free to download the base or your existing ACL file from your tailnet admin panel to start
4. `terraform init`
5. `terraform plan`
6. `terraform apply --auto-approve`

## TODO

Profile Management: Associate an ACL file per tailnet with it's own Oauth credentials so you can sync multiple ACLs to their respective tailnets
