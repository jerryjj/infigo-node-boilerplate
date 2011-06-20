#!/bin/bash

# === FUNCTIONS ===
# --- print and exit functions ---
function print_info()
{
  echo " -- $1"
}
          
function print_warn()
{
  echo " ** $1"
}
 
function force_exit()   
{
  echo " !! $2, exiting..."
  show_help
  exit $1
}

function safe_exit()
{
  echo " -- Safely exiting..."
  cleanup
  show_launch_help
  exit 0
}

function show_help()
{
  cat << EOF
  usage: $0

  This script prepares project.
EOF
}

function show_launch_help()
{
  echo ""
  print_info "If you see no error or notifications up, then"
  print_info "you can launch your project with command"
  print_info "coffee app.coffee"
  echo ""
}

# --- helper functions ---
function cleanup()
{
  print_info "Cleaning up"
}

function create_dir()
{
	if [ ! -d $1 ]; then
		print_info "Creating directory: $1"

		mkdir -p $1 # if $1 doesn't exist, create it
		if [ $? -ne 0 ]; then
			force_exit 1 "Could not create $1"
		fi
	fi
}

echo ""
print_info "Preparing project"

# === LOGIC ===

function init_submodules()
{
  print_info "Initializing git submodules"
  
  #git submodule update --init --recursive
  git submodule init && git submodule update
}

function install_npm_dependencies()
{
  print_info "Installing npm dependencies (locally)"
  
  npm install --local
  echo " -- "
}

init_submodules
install_npm_dependencies

safe_exit