This is project template for Node.js based project we create in our company.
It is written with Coffee-Script.
It uses Express.js and Jade as template language
It also has user authentication and authorization implemented.
As storage it support either MySQL, Drizzle or MongoDB

## User authorization details

There are users, groups and roles
User can belong to any number of groups
Roles can be assigned to groups and users
Groups and Users can have many roles

To check roles in routes (urls) one just has to call Auth.requireRole with space separated list of roles required. (see routes/admin/index.coffee)
Missing roles are created automatically.

Currently project doesn't include routes for managing user,groups or roles, but this is coming soon.

# To create new project

1. Clone as project name. (ie. "git clone git@github.com:jerryjj/infigo-node-boilerplate.git projectx")
2. Go to project dir (ie. cd projectx)
3. Run ./bin/initproject.sh --name projectx --type mysql

  --type can be "mysql","drizzle","mongo" defaults to "mysql"
  Additional arguments for initproject.sh: (more info ./bin/initproject.sh --help)

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
