set :stages, %w[staging production]
set :default_stage, 'staging'
require 'capistrano/ext/multistage'

set :node_env, "staging"
set :application, "[PROJECT]"
set :node_file, "app.coffee"
set :host, "[PROJECT_HOST]"
set :repository, "[PROJECT_GIT]"
set :user, "[DEPLOY_USER]"
set :admin_runner, "[DEPLOY_USER]"

set :scm, :git
set :deploy_via, :remote_cache
role :app, host
set :deploy_to, "/var/www/apps/#{application}/#{node_env}"
set :use_sudo, true
default_run_options[:pty] = true

namespace :deploy do
  task :start, :roles => :app, :except => { :no_release => true } do
    sudo "start #{application}_#{node_env}"
  end

  task :stop, :roles => :app, :except => { :no_release => true } do
    sudo "stop #{application}_#{node_env}"
  end

  task :restart, :roles => :app, :except => { :no_release => true } do
    sudo "restart #{application}_#{node_env} || sudo start #{application}_#{node_env}"
  end

  task :create_deploy_to_with_sudo, :roles => :app do
    sudo "mkdir -p #{deploy_to}"
    sudo "chown #{admin_runner}:#{admin_runner} #{deploy_to}"
  end

  desc "Update submodules"
  task :update_submodules, :roles => :app do
    run "cd #{release_path}; git submodule init && git submodule update"
  end
  
  desc "Check required packages and install if packages are not installed"
  task :check_packages, :roles => :app do
    run "cd #{release_path}"
    sudo "jake depends"
  end
  
  desc "Set default database contents"
  task :fill_database, :roles => :app do
    run "NODE_ENV=#{node_env} /usr/local/bin/coffee #{release_path}/init_db.coffee"
  end

  task :write_upstart_script, :roles => :app do
    upstart_script = <<-UPSTART
description "#{application}"

start on startup
stop on shutdown

script
# $HOME is needed. Without it, we ran into problems
export HOME="/home/#{admin_runner}"
export NODE_ENV="#{node_env}"

cd #{current_path}
exec sudo -u #{admin_runner} sh -c "NODE_ENV=#{node_env} PORT=#{application_port} /usr/local/bin/coffee #{current_path}/#{node_file} >> #{shared_path}/log/#{node_env}.log 2>&1"
end script
respawn
UPSTART
  put upstart_script, "/tmp/#{application}_upstart.conf"
    sudo "mv /tmp/#{application}_upstart.conf /etc/init/#{application}_#{node_env}.conf"
  end
  
  task :finalize_update, :roles => :app do
  end

end

before 'deploy:setup', 'deploy:create_deploy_to_with_sudo'
after 'deploy:setup', 'deploy:write_upstart_script'
after "deploy:finalize_update", "deploy:update_submodules", "deploy:check_packages", "deploy:fill_database"
