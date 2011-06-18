###
Setup Dependencies
###
require.paths.unshift __dirname
s = require __dirname + "/lib/setup"
s.ext __dirname + "/lib"
s.ext __dirname + "/support"

mongoose = require 'mongoose'
express = require 'express'
sys = require 'sys'
models = require './models'
CoffeeScript = require 'coffee-script'

app = module.exports = express.createServer()

tmpcfg = require('yaml').eval(
  require('fs')
  .readFileSync('config/app_config.yml')
  .toString('utf-8')
)
global.config = CoffeeScript.helpers.merge tmpcfg['common'], tmpcfg[app.settings.env]

app.set 'db_type', global.config.db_type
app.set 'db-uri', global.config.db_uri

app.configure 'development', () ->
  console.log "configure development"
  app.use express.errorHandler(dumpExceptions: true, showStack: true)
  
app.configure 'staging', () ->
  console.log "configure staging"
  app.use express.errorHandler(dumpExceptions: true, showStack: true)

app.configure 'test', () ->
  console.log "configure test"

app.configure 'production', () ->
  console.log "configure production"  
  app.use express.errorHandler()

User = Group = GroupUser = Role = RoleGroup = Instruction = db = null

models.defineModels mongoose, () ->
  db = mongoose.connect app.set('db-uri')

  app.User = User = mongoose.model 'User'
  app.Group = Group = mongoose.model 'Group'
  app.GroupUser = GroupUser = mongoose.model 'GroupUser'
  app.Role = Role = mongoose.model 'Role'
  app.RoleGroup = RoleGroup = mongoose.model 'RoleGroup'
    
# Create default user
console.log "Creating default user 'admin' with password admin"
u = new User {
  username: 'admin'
  password: 'admin'
  email: 'admin@project.com'
  'name.first': 'Project'
  'name.last': 'Admin'
}
u.save (err, usr) ->
  if err
    console.log 'User save error'
    console.log err
    process.exit 0

  console.log "User created"
  console.log "Creating default group and roles"

  gu = new GroupUser {
    user_id: usr.id
    username: usr.username
    'name.first': usr.name.first
    'name.last': usr.name.last
    'name.full': usr.name.full
  }

  g = new Group {
    name: 'Admins'
    users: [gu.toObject()]
  }
  g.save (err, grp) ->
    if err
      console.log 'Group save error'
      console.log err
      process.exit 0

    console.log "Created group 'Admins'"

    rg = new RoleGroup {
      group_id: grp.id
      name: grp.name
    }

    r = new Role {
      key: 'admin'
      groups: [rg.toObject()]
    }
    r.save (err) ->
      if err
        console.log 'Role save error'
        console.log err
        process.exit 0

      console.log "Created role 'admin'"
      process.exit 0