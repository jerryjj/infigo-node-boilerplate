#!/bin/bash

# === FUNCTIONS ===
# --- print and exit functions ---
function print_info()
{
  echo " -- $1"
}
          
function print_warn()
{
  echo " ** $1. You may want to look into this, continuing..."
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
  #echo "Usage: $0 --name=project_name --type=(mysql|drizzle|mongo) [--deploy.port.staging=] [--deploy.port.production=] [--deploy.user=] [--deploy.host=] [--git.remote=]"
  cat << EOF
  usage: $0 -n project_name [additional_options]

  This script prepares project boilerplate.
  
  OPTIONS
     -n --name                             Name of the project (lowercase)
  ADDITIONAL OPTIONS:
     -h --help                             Show this message
     -t --type (mysql|drizzle|mongo)       Projects storage type (DEFAULT: mysql)
     --deploy.port.staging                 Deploy port (staging)
     --deploy.port.production              Deploy port (production)
     --deploy.user                         Deploy as user
     --deploy.host                         Deploy host
     --git.remote                          Git remote url

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

PROJECT_NAME=""
PROJECT_TYPE="mysql"
DEPLOY_PORT_STAGING=1200
DEPLOY_PORT_PRODUCTION=1300
DEPLOY_USER="root"
DEPLOY_HOST=""
GIT_REMOTE=""

# translate long options to short
for arg
do
    delim=""
    case "$arg" in
       --help) args="${args}-h ";;
       --name) args="${args}-n ";;
       --type) args="${args}-t ";;
       --deploy.port.staging) args="${args}-1 ";;
       --deploy.port.production) args="${args}-2 ";;
       --deploy.user) args="${args}-3 ";;
       --deploy.host) args="${args}-4 ";;
       --git.remote) args="${args}-5 ";;
       # pass through anything else
       *) [[ "${arg:0:1}" == "-" ]] || delim="\""
           args="${args}${delim}${arg}${delim} ";;
    esac
done
eval set -- $args
while getopts "hn:t:1:2:3:4:5:" OPTION
do
   case $OPTION in
     h)
       show_help
       exit 1
       ;;
     n)
       PROJECT_NAME=$OPTARG
       ;;
     t)
       PROJECT_TYPE=$OPTARG
       ;;
     1)
       DEPLOY_PORT_STAGING=$OPTARG
       ;;
     2)
       DEPLOY_PORT_PRODUCTION=$OPTARG
       ;;
     3)
       DEPLOY_USER=$OPTARG
       ;;
     4)
       DEPLOY_HOST=$OPTARG
       ;;
     5)
       GIT_REMOTE=$OPTARG
       ;;
     \?)
       show_help
       exit 1
       ;;
   esac
done

if [[ -z $PROJECT_NAME ]] || [[ -z $PROJECT_TYPE ]]; then
   force_exit 1 "Improper number of parameters ($#)"
fi

if [ $PROJECT_NAME == "" ]; then
  force_exit 1 "Project name required!"
fi

if [[ $PROJECT_TYPE != "mysql" ]] && [[ $PROJECT_TYPE != "drizzle" ]] && [[ $PROJECT_TYPE != "mongo" ]]; then
  force_exit 1 "unkown type $PROJECT_TYPE"
fi

if [[ $DEPLOY_HOST != "" ]] && [[ $GIT_REMOTE == "" ]]; then
  force_exit 1 "git.remote cannot be empty if deploy host is set"
fi

echo ""
print_info "Preparing project $PROJECT_NAME with type $PROJECT_TYPE"
if [[ $DEPLOY_HOST != "" ]]; then
  print_info "Deploying config"
  print_info "  Host: $DEPLOY_HOST"
  print_info "  User: $DEPLOY_USER"
  print_info "  Staging port: $DEPLOY_PORT_STAGING"
  print_info "  Production port: $DEPLOY_PORT_PRODUCTION"
  print_info "  Remote Git url: $GIT_REMOTE"
fi

# === LOGIC ===

function init_submodules()
{
  print_info "Initializing git submodules"
  
  #git submodule update --init --recursive
  git submodule init && git submodule update
}

function prepare_statics()
{
  print_info "Preparing static files"
  
  create_dir "$PWD/static/img"
  create_dir "$PWD/static/swf"
  
  cp "$PWD/support/html5-boilerplate/js/plugins.js" "$PWD/static/js/plugins.js"
  cp "$PWD/support/html5-boilerplate/js/script.js" "$PWD/static/js/application.js"
  cp "$PWD/support/html5-boilerplate/css/handheld.css" "$PWD/static/css/handheld.css"
  cp "$PWD/support/html5-boilerplate/css/style.css" "$PWD/static/css/style.css"
  cp "$PWD/support/html5-boilerplate/robots.txt" "$PWD/static/robots.txt"
}

function prepare_deploy_config()
{
  print_info "Preparing deploy config"
  
  cp "$PWD/config/deploy.rb" "$PWD/config/deploy.rb-tmp"
  DF="$PWD/config/deploy.rb"
  GIT_REMOTE=$(echo $GIT_REMOTE | sed -e 's/\//\\\//g')
  
  cat "$DF" | sed -e "s/\[PROJECT\]/$PROJECT_NAME/g" -e "s/\[PROJECT_HOST\]/'$DEPLOY_HOST'/g" -e 's/\[PROJECT_GIT\]/'"$GIT_REMOTE"'/g' -e 's/\[PROJECT_HOST\]/'"$DEPLOY_HOST"'/g'  -e "s/\[DEPLOY_USER\]/$DEPLOY_USER/g" > "$DF-tmp"
  mv "$PWD/config/deploy.rb-tmp" "$PWD/config/deploy.rb"
  
  # config/deploy/production.rb
  cp "$PWD/config/deploy/production.rb" "$PWD/config/deploy/production.rb-tmp"
  DF="$PWD/config/deploy/production.rb"
  
  cat "$DF" | sed -e "s/\[PRODUCTION_PORT\]/$DEPLOY_PORT_PRODUCTION/g" > "$DF-tmp"
  mv "$PWD/config/deploy/production.rb-tmp" "$PWD/config/deploy/production.rb.rb"
  
  # config/deploy/staging.rb
  cp "$PWD/config/deploy/staging.rb" "$PWD/config/deploy/staging.rb-tmp"
  DF="$PWD/config/deploy/staging.rb"
  
  cat "$DF" | sed -e "s/\[STAGING_PORT\]/$DEPLOY_PORT_STAGING/g" > "$DF-tmp"
  mv "$PWD/config/deploy/staging.rb-tmp" "$PWD/config/deploy/staging.rb.rb"
}

function prepare_project_config()
{
  print_info "Preparing project config"
  
  if [[ $PROJECT_TYPE == "mysql" ]] || [[ $PROJECT_TYPE == "drizzle" ]]; then
    cp "$PWD/config/app_config-sql.yml" "$PWD/config/app_config-sql.yml-tmp"
    DF="$PWD/config/app_config-sql.yml"

    cat "$DF" | sed -e "s/\[DB_TYPE\]/$PROJECT_TYPE/g" -e "s/\[PROJECT\]/$PROJECT_NAME/g" > "$DF-tmp"
    mv "$PWD/config/app_config-sql.yml-tmp" "$PWD/config/app_config.yml"
    rm "$DF"
    rm "$PWD/config/app_config-mongo.yml"
  else
    cp "$PWD/config/app_config-mongo.yml" "$PWD/config/app_config-mongo.yml-tmp"
    DF="$PWD/config/app_config-mongo.yml"

    cat "$DF" | sed -e "s/\[DB_TYPE\]/$PROJECT_TYPE/g" -e "s/\[PROJECT\]/$PROJECT_NAME/g" > "$DF-tmp"
    mv "$PWD/config/app_config-mongo.yml-tmp" "$PWD/config/app_config.yml"
    rm "$DF"
    rm "$PWD/config/app_config-sql.yml"
  fi
  
  if [[ $PROJECT_TYPE == "mysql" ]] || [[ $PROJECT_TYPE == "drizzle" ]]; then
    cp "$PWD/package-sql.json" "$PWD/package-sql.json-tmp"
    DF="$PWD/package-sql.json"

    cat "$DF" | sed -e "s/\[DB_TYPE\]/$PROJECT_TYPE/g" -e "s/\[PROJECT\]/$PROJECT_NAME/g" > "$DF-tmp"
    mv "$PWD/package-sql.json-tmp" "$PWD/package.json"
    rm "$DF"
    rm "$PWD/package-mongo.json"
    
    cp "$PWD/config/requirements-sql.json" "$PWD/config/requirements-sql.json-tmp"
    DF="$PWD/config/requirements-sql.json"

    cat "$DF" | sed -e "s/\[DB_TYPE\]/$PROJECT_TYPE/g" -e "s/\[PROJECT\]/$PROJECT_NAME/g" > "$DF-tmp"
    mv "$PWD/config/requirements-sql.json-tmp" "$PWD/config/requirements.json"
    rm "$DF"
    rm "$PWD/config/requirements-mongo.json"
  else
    cp "$PWD/package-mongo.json" "$PWD/package-mongo.json-tmp"
    DF="$PWD/package-mongo.json"

    cat "$DF" | sed -e "s/\[DB_TYPE\]/$PROJECT_TYPE/g" -e "s/\[PROJECT\]/$PROJECT_NAME/g" > "$DF-tmp"
    mv "$PWD/package-mongo.json-tmp" "$PWD/package.json"
    rm "$DF"
    rm "$PWD/package-sql.json"
    
    mv "$PWD/config/requirements-mongo.json" "$PWD/config/requirements.json"
    rm "$PWD/config/requirements-sql.json"
  fi
}

function prepare_type_sql_common()
{
  mv "$PWD/app-sql.coffee" "$PWD/app.coffee"
  mv "$PWD/init_db-sql.coffee" "$PWD/init_db.coffee"
  mv "$PWD/lib/authorization-sql.coffee" "$PWD/lib/authorization.coffee"
  
  rm "$PWD/app-mongo.coffee"
  rm "$PWD/init_db-mongo.coffee"  
  rm "$PWD/models.coffee"
  rm "$PWD/lib/authorization-mongo.coffee"
}
function prepare_type_mysql()
{
  print_info "Preparing MySQL type"
  prepare_type_sql_common
}
function prepare_type_drizzle()
{ 
  print_info "Preparing Drizzle type"
  prepare_type_sql_common
}
function prepare_type_mongo()
{
  print_info "Preparing MongoDB type"
  mv "$PWD/app-mongo.coffee" "$PWD/app.coffee"
  mv "$PWD/init_db-mongo.coffee" "$PWD/init_db.coffee"
  mv "$PWD/lib/authorization-mongo.coffee" "$PWD/lib/authorization.coffee"
  
  rm "$PWD/app-sql.coffee"
  rm "$PWD/init_db-sql.coffee"
  rm "$PWD/lib/authorization-sql.coffee"
  rm "$PWD/database.sql"
}

function cleanup_template_git()
{
  print_info "Cleaning template project"
  rm -fR "$PWD/.git"
  echo "bin/initproject.sh" >> "$PWD/.gitignore"
}

function initialize_project_git()
{
  print_info "Initializing new Git project"
  git init  
  git add *  
  git add .gitmodules
  git add .gitignore
  git submodule init
  git commit -a -m "Initial commit"
  
  if [[ $GIT_REMOTE != "" ]]; then
    git remote add origin $GIT_REMOTE    
  fi
}

function initialize_project_storage()
{
  print_info "Initializing project storage"

  if [[ $PROJECT_TYPE == "mysql" ]] || [[ $PROJECT_TYPE == "drizzle" ]]; then
    print_info "Create configured database and user. Then run 'coffee init_db.coffee' in project dir ($PWD)."
  else
    coffee "$PWD/init_db.coffee"
  fi
}

function install_npm_dependencies()
{
  print_info "Installing npm dependencies (locally)"
  
  npm install --local
  echo " -- "
}

init_submodules
prepare_statics

prepare_deploy_config
prepare_project_config

if [ "$PROJECT_TYPE" == "mysql" ]; then
  prepare_type_mysql
elif [ "$PROJECT_TYPE" == "drizzle" ]; then
  prepare_type_drizzle
elif [ "$PROJECT_TYPE" == "mongo" ]; then
  prepare_type_mongo
fi

cleanup_template_git
initialize_project_git

install_npm_dependencies

initialize_project_storage

safe_exit