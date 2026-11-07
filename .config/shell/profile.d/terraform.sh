#!/bin/bash
# Terraform's plugin_cache_dir (~/.terraformrc) must already exist; Terraform won't create it.

mkdir -p "$HOME/.cache/terraform-plugins"
