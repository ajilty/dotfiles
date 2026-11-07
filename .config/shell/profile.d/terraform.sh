#!/bin/bash
# Folder for plugin_cache_dir in ~/.terraformrc. Terraform's docs require it to exist first.

mkdir -p "$HOME/.cache/terraform-plugins" 2>/dev/null || true
