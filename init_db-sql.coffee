###
Setup Dependencies
###
require.paths.unshift __dirname
s = require __dirname + "/lib/setup"
s.ext __dirname + "/lib"
s.ext __dirname + "/support"

express = require 'express'
sys = require 'sys'

CoffeeScript = require 'coffee-script'

Auth = require 'authorization'

app = module.exports = express.createServer()

tmpcfg = require('yaml').eval(
  require('fs')
  .readFileSync('config/app_config.yml')
  .toString('utf-8')
)
global.config = CoffeeScript.helpers.merge tmpcfg['common'], tmpcfg[app.settings.env]

app.set 'db_type', global.config.db_type
app.set 'db_user', global.config.db_user
app.set 'db_pass', global.config.db_pass
app.set 'db_name', global.config.db_name

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

db = require('db-mysql')[app.set('db_type')].Database(
  hostname: app.set 'db_host'
  port: app.set 'db_port'
  database: app.set 'db_name'
  user: app.set 'db_user'
  password: app.set 'db_pass'  
).on('error', (error) ->
    console.log 'ERROR connecting to SQL server: ' + error
).on('ready', (server) ->
    console.log 'Connected to ' + server.hostname + ' (' + server.version + ')'
    
    console.log 'creating table users'
    app.sqlClient.query().execute(
      "CREATE TABLE IF NOT EXISTS `users` (
          `id` bigint unsigned NOT NULL auto_increment,
          `username` varchar(255) NOT NULL DEFAULT '',
          `hashed_password` varchar(255) NOT NULL DEFAULT '',
          `salt` varchar(255) NOT NULL DEFAULT '',
          `firstname` varchar(255) NOT NULL DEFAULT '',
          `lastname` varchar(255) NOT NULL DEFAULT '',
          `email` varchar(255) NOT NULL DEFAULT '',
          `status` int unsigned NOT NULL DEFAULT 0,
          PRIMARY KEY (`id`),
          UNIQUE KEY (`username`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
      (err) ->
        if err
          throw err
        
        
        console.log "Creating default user 'admin' with password admin"
        salt = Auth.makeSalt()        
        app.sqlClient.query().
          insert('users',
            ['firstname', 'lastname', 'username', 'salt', 'hashed_password', 'email'],
            ['Project', 'Admin', 'admin', salt, Auth.createHashedPassword(salt, 'admin'), 'admin@project.com']
          ).execute (err, result) ->
            if err
              console.log 'ERROR creating user: ' + err
              throw err
            console.log 'User created with id: %s', result.id
    )
    
    console.log 'creating table groups'
    app.sqlClient.query().execute(
      "CREATE TABLE IF NOT EXISTS `groups` (
          `id` bigint unsigned NOT NULL auto_increment,
          `name` varchar(255) NOT NULL DEFAULT '',
          PRIMARY KEY (`id`),
          UNIQUE KEY (`name`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
      (err) ->
        if err
          throw err
          
        console.log "Creating default group 'Admins'"        
        app.sqlClient.query().
          insert('groups',
            ['name'],
            ['Admins']
          ).execute (err, result) ->
            if err
              console.log 'ERROR creating group: ' + err
              throw err
            console.log 'Group created with id: %s', result.id
    )
    
    console.log 'creating table group_users'
    app.sqlClient.query().execute(
      "CREATE TABLE IF NOT EXISTS `group_users` (
          `id` bigint unsigned NOT NULL auto_increment,
          `group_id` bigint NOT NULL DEFAULT 0,
          `user_id` bigint NOT NULL DEFAULT 0,
          PRIMARY KEY (`id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
      (err) ->
        if err
          throw err
          
        console.log "Assigning user 'admin' to grou 'Admins'"
        app.sqlClient.query().
          insert('group_users',
            ['group_id', 'user_id'],
            [1, 1]
          ).execute (err, result) ->
            if err
              console.log 'ERROR assigning user to group: ' + err
              throw err
            console.log 'Group assigment created with id: %s', result.id
    )
    
    console.log 'creating table roles'
    app.sqlClient.query().execute(
      "CREATE TABLE IF NOT EXISTS `roles` (
          `id` bigint unsigned NOT NULL auto_increment,
          `key` varchar(255) NOT NULL DEFAULT '',
          PRIMARY KEY (`id`),
          UNIQUE KEY (`key`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
      (err) ->
        if err
          throw err
          
      console.log "Creating default role 'admin'"
      app.sqlClient.query().
        insert('roles',
          ['key'],
          ['admin']
        ).execute (err, result) ->
          if err
            console.log 'ERROR creating role: ' + err
            throw err
          console.log 'Role created with id: %s', result.id
    )
    
    console.log 'creating table role_users'
    app.sqlClient.query().execute(
      "CREATE TABLE IF NOT EXISTS `role_users` (
          `id` bigint unsigned NOT NULL auto_increment,
          `role_id` bigint NOT NULL DEFAULT 0,
          `user_id` bigint NOT NULL DEFAULT 0,
          PRIMARY KEY (`id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
      (err) ->
        if err
          throw err
          
        console.log "Assigning user 'admin' to role 'admin'"
        app.sqlClient.query().
          insert('role_users',
            ['role_id', 'user_id'],
            [1, 1]
          ).execute (err, result) ->
            if err
              console.log 'ERROR assigning user to role: ' + err
              throw err
            console.log 'Role assigment created with id: %s', result.id
    )
    
    console.log 'creating table role_groups'
    app.sqlClient.query().execute(
      "CREATE TABLE IF NOT EXISTS `role_groups` (
          `id` bigint unsigned NOT NULL auto_increment,
          `role_id` bigint NOT NULL DEFAULT 0,
          `group_id` bigint NOT NULL DEFAULT 0,
          PRIMARY KEY (`id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
      (err) ->
        if err
          throw err
          
        console.log "Assigning group 'Admins' to role 'admin'"
        app.sqlClient.query().
          insert('role_groups',
            ['role_id', 'group_id'],
            [1, 1]
          ).execute (err, result) ->
            if err
              console.log 'ERROR assigning group to role: ' + err
              throw err
            console.log 'Role assigment created with id: %s', result.id
    )
    
    setTimeout( () ->
      process.exit 0
    , 1000)
)
app.sqlClient.connect()