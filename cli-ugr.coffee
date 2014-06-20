#!/usr/bin/env coffee
_ = require 'underscore'
winston = require 'winston'
logger = new winston.Logger {
  transports: [
    new winston.transports.Console { handleExceptions:true}
    new winston.transports.File { filename: 'all-logs.log', handleExceptions:true}
  ]
}
cmdlogger = new winston.Logger {
  transports: [
    new winston.transports.File { filename: 'all-logs.log'}
  ]
}
#argv
opt = require('optimist')
  .usage('CLI for user, group and role management')
  .alias('L','List')
  .describe('L','List action on (specified) user, group or role')
  .alias('U','Update')
  .describe('U','Update action on specified user, group or role, will create new one if not exist')
  .alias('D','Delete')
  .describe('D','Delete action on specified user, group or role')
  .alias('u','user')
  .describe('u','Specify a user, or list all users')
  .alias('g','group')
  .describe('g','Specify a group, or list all groups')
  .alias('r','role')
  .describe('r','Sepcify a role, or list all roles')
  .alias('p','password')
  .describe('p','Sepcify password of the user to update or create')
  .alias('a','adduser')
  .describe('a','use with --Update, add user to specified --group')
  .alias('b','removeuser')
  .describe('b','use with --Update, remove user from specified --group')
  .alias('c', 'addgroup')
  .describe('c','use with --Update, add group to specified --role')
  .alias('d', 'removegroup')
  .describe('d','use with --Update, remove group from specified --role')
  
argv = opt.argv

check = ()->
  # LUD
    actionCount = _.compact([argv.L, argv.D, argv.U]).length
    if  actionCount > 1
      console.log 'Options Error: only 1 action allowed, you specified: ' + actionCount + '\n'
      return false
    if actionCount == 0
      console.log 'Options Error: you did not speicfy any action\n'
      return false
    # ugr
    ugrCount = _.compact([argv.u, argv.g, argv.r]).length
    if ugrCount > 1
      console.log 'Options Error: only 1 of --user, --group or --role is allowed, you specified: ' + ugrCount + '\n'
      return false
    if ugrCount == 0
      console.log 'Options Error: you did not speicfy --user, --group or --role\n'
      return false
    # ab
    abCount = _.compact([argv.a, argv.b]).length
    if abCount > 1
      console.log 'Options Error: only 1 of --adduser or --removeuser is allowed, you specified: ' + abCount + '\n'
      return false
    # cd
    cdCount = _.compact([argv.c, argv.d]).length
    if cdCount > 1
      console.log 'Options Error: only 1 of --addgroup or --removegroup is allowed, you specified: ' + cdCount + '\n'
      return false
    # console.log argv
    return true

if not check()
  opt.showHelp()
  process.exit 0

cmdlogger.debug 'argv', agrv:argv, pargv:process.argv
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
app.set 'pg-uri', global.config.pg_uri

app.configure 'development', () ->
  logger.info "configure development"
  app.use express.errorHandler(dumpExceptions: true, showStack: true)
  
app.configure 'staging', () ->
  logger.info "configure staging"
  app.use express.errorHandler(dumpExceptions: true, showStack: true)

app.configure 'test', () ->
  logger.info "configure test"

app.configure 'production', () ->
  logger.info "configure production"
  app.use express.errorHandler()

User = Group = GroupUser = Role = RoleGroup = Instruction = db = null

models.defineModels mongoose, () ->
  db = mongoose.connect app.set('db-uri')
  app.User = User = mongoose.model 'User'
  app.Group = Group = mongoose.model 'Group'
  app.GroupUser = GroupUser = mongoose.model 'GroupUser'
  app.Role = Role = mongoose.model 'Role'
  app.RoleGroup = RoleGroup = mongoose.model 'RoleGroup'

Mgr = require 'ugrManager'

logExit = (err,docs) ->
  console.log docs
  end()

rejectTrue = (arg, other)->
  if argv[arg] == true
    logger.info "--#{arg} need to be specified"
    # need a query callback to close, otherwise not work, maybe due to connection is not ready
    endNothing()
  else
    other()

end = ()->
  User.findOne username:'none', ()->
    mongoose.disconnect()

endNothing = ()->
  logger.info 'nothing changed'
  end()

# List
if argv.List
  logger.info 'List action'
  # user
  if argv.user
    if argv.user == true
      User.count {}, (err,docs)->
        logger.info 'user count: ' + docs
      User.find {}, logExit
    else
      logger.info 'user: ' + argv.user
      Mgr.listUser argv.user, logExit
  # group
  else if argv.group
    if argv.group == true
      Group.count {}, (err,docs)->
        logger.info 'group count: ' + docs
      Group.find {}, logExit
    else
      logger.info 'group: ' + argv.group
      Mgr.listGroup argv.group, logExit
  # role
  else if argv.role
    if argv.role == true
      Role.count {}, (err,docs)->
        logger.info 'role count: ' + docs
      Role.find {}, logExit
    else
      logger.info 'role: ' + argv.role
      Mgr.listRole argv.role, logExit

# Delete
else if argv.Delete
  logger.info 'Delete action'
  # user
  if argv.user
    rejectTrue 'user', ()->
      Mgr.deleteUser argv.user, (err)-> end()
  # group
  else if argv.group
    rejectTrue 'group', ()->
      Mgr.deleteGroup argv.group, (err)-> end()
  # role
  else if argv.role
    rejectTrue 'role', ()->
      Mgr.deleteRole argv.role, (err)-> end()

# Update
else if argv.Update
  logger.info 'Update action'
  # user
  if argv.user
    rejectTrue 'user', ()->
      rejectTrue 'password', ()->
        if argv.password
          Mgr.updateUserWithPassword argv.user, argv.password, (err,user)->
            console.log user
            end()
        else
          logger.info '--password need to be specified'
          endNothing()

  # group
  else if argv.group
    rejectTrue 'group', ()->
      Mgr.createGroupUnlessExist argv.group, (err, group) ->
        if err
          end()
        else if argv.adduser
          rejectTrue 'adduser', ()->
            Mgr.addUserToGroup argv.adduser, group, (err) -> end()
        else if argv.removeuser
          rejectTrue 'removeuser', ()->
            Mgr.removeUserFromGroup argv.removeuser, group, (err) -> end()
        else
          logExit err, group
  # role
  else if argv.role
    rejectTrue 'role',()->
      Mgr.createRoleUnlessExist argv.role, (err, role) ->
        if err
          end()
        else if argv.addgroup
          rejectTrue 'addgroup', ()->
            Mgr.addGroupToRole argv.addgroup, role, (err) -> end()
        else if argv.removegroup
          rejectTrue 'removegroup', ()->
            Mgr.removeGroupFromRole argv.removegroup, role, (err) -> end()
        else
          logExit err, role

