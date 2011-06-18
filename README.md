# To create new project

1. Clone as project name. (ie. "git clone git@github.com:jerryjj/infigo-node-boilerplate.git projectx")
2. Go to project dir (ie. cd projectx)
3. Run ./bin/initproject.sh --name=projectx --type=mysql
3.1 --type can be "mysql","drizzle","mongo" defaults to "mysql"
3.2 Additional arguments for initproject.sh
* --deploy.port.staging default: 1200
* --deploy.port.production default: 1300
* --deploy.user default: root (ie. --deploy.user=linuxuser)
* --deploy.host (ie. --deploy.host=projectx.com)
* --git.remote (ie. --git.remote=git@github.com:jerryjj/projectx.git)

# Deploy to server

## Requirements

### Locally
- capistrano

### Remotely
- node
- npm
- jake

If deploy.* and git.remote options were configured when initproject.sh was run, (or configured manually to config/deploy.rb)
One can run
1. cap staging deploy:setup
2. cap staging deploy
OR
1. cap production deploy:setup
2. cap production deploy
