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
app.set 'db_host', global.config.db_host
app.set 'db_port', global.config.db_port
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

db = require('db-'+app.set('db_type')).Database
app.sqlClient = new db(
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
          `id` bigint NOT NULL auto_increment,
          `username` varchar(255) NOT NULL DEFAULT '',
          `hashed_password` varchar(255) NOT NULL DEFAULT '',
          `salt` varchar(255) NOT NULL DEFAULT '',
          `firstname` varchar(255) NOT NULL DEFAULT '',
          `lastname` varchar(255) NOT NULL DEFAULT '',
          `email` varchar(255) NOT NULL DEFAULT '',
          `last_login` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
          PRIMARY KEY (`id`),
          UNIQUE KEY (`username`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;",
      (err) ->        
        if err
          throw err
        console.log 'users table created'
        
        console.log "Creating default user 'admin' with password admin"
        salt = Auth.makeSalt()        
        app.sqlClient.query().
          insert('users',
            ['id', 'firstname', 'lastname', 'username', 'salt', 'hashed_password', 'email'],
            [1, 'Project', 'Admin', 'admin', salt, Auth.createHashedPassword(salt, 'admin'), 'admin@project.com']
          ).execute (err, result) ->
            if err
              console.log 'ERROR creating user: ' + err
            else if result
              console.log 'User created with id: %s', result.id
    )
    
    console.log 'creating table groups'
    app.sqlClient.query().execute(
      "CREATE TABLE IF NOT EXISTS `groups` (
          `id` bigint NOT NULL auto_increment,
          `name` varchar(255) NOT NULL DEFAULT '',
          PRIMARY KEY (`id`),
          UNIQUE KEY (`name`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;",
      (err) ->        
        if err
          throw err
        console.log 'groups table created'
          
        console.log "Creating default group 'Admins'"        
        app.sqlClient.query().
          insert('groups',
            ['id', 'name'],
            [1, 'Admins']
          ).execute (err, result) ->
            if err
              console.log 'ERROR creating group: ' + err
            else if result
              console.log 'Group created with id: %s', result.id
    )
    
    console.log 'creating table group_users'
    app.sqlClient.query().execute(
      "CREATE TABLE IF NOT EXISTS `group_users` (
          `id` bigint NOT NULL auto_increment,
          `group_id` bigint NOT NULL DEFAULT 0,
          `user_id` bigint NOT NULL DEFAULT 0,
          PRIMARY KEY (`id`),
          KEY `group_id` USING BTREE (`group_id`),
          FOREIGN KEY (`group_id`) REFERENCES `groups`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
          KEY `user_id` USING BTREE (`user_id`),
          FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;",
      (err) ->        
        if err
          throw err
        console.log 'group_users table created'
          
        console.log "Assigning user 'admin' to group 'Admins'"
        app.sqlClient.query().
          insert('group_users',
            ['id', 'group_id', 'user_id'],
            [1, 1, 1]
          ).execute (err, result) ->
            if err
              console.log 'ERROR assigning user to group: ' + err
            else if result
              console.log 'Group assigment created with id: %s', result.id
    )
    
    console.log 'creating table roles'
    app.sqlClient.query().execute(
      "CREATE TABLE IF NOT EXISTS `roles` (
          `id` bigint NOT NULL auto_increment,
          `name` varchar(255) NOT NULL DEFAULT '',
          PRIMARY KEY (`id`),
          UNIQUE KEY (`name`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;",
      (err) ->        
        if err
          throw err
        console.log 'roles table created'
          
        console.log "Creating default role 'admin'"
        app.sqlClient.query().
          insert('roles',
            ['id', 'name'],
            [1, 'admin']
          ).execute (err, result) ->
            if err
              console.log 'ERROR creating role: ' + err
            else if result
              console.log 'Role created with id: %s', result.id
    )
    
    console.log 'creating table role_users'
    app.sqlClient.query().execute(
      "CREATE TABLE IF NOT EXISTS `role_users` (
          `id` bigint NOT NULL auto_increment,
          `role_id` bigint NOT NULL DEFAULT 0,
          `user_id` bigint NOT NULL DEFAULT 0,
          PRIMARY KEY (`id`),
          KEY `role_id` USING BTREE (`role_id`),
          FOREIGN KEY (`role_id`) REFERENCES `roles`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
          KEY `user_id` USING BTREE (`user_id`),
          FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;",
      (err) ->        
        if err
          throw err
        console.log 'role_users table created'
          
        console.log "Assigning user 'admin' to role 'admin'"
        app.sqlClient.query().
          insert('role_users',
            ['id', 'role_id', 'user_id'],
            [1, 1, 1]
          ).execute (err, result) ->
            if err
              console.log 'ERROR assigning user to role: ' + err
            else if result
              console.log 'Role assigment created with id: %s', result.id
    )
    
    console.log 'creating table role_groups'
    app.sqlClient.query().execute(
      "CREATE TABLE IF NOT EXISTS `role_groups` (
          `id` bigint NOT NULL auto_increment,
          `role_id` bigint NOT NULL DEFAULT 0,
          `group_id` bigint NOT NULL DEFAULT 0,
          PRIMARY KEY (`id`),
          KEY `role_id` USING BTREE (`role_id`),
          FOREIGN KEY (`role_id`) REFERENCES `roles`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
          KEY `group_id` USING BTREE (`group_id`),
          FOREIGN KEY (`group_id`) REFERENCES `groups`(`id`) ON DELETE CASCADE ON UPDATE NO ACTION
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;",
      (err) ->        
        if err
          throw err
        console.log 'role_groups table created'
          
        console.log "Assigning group 'Admins' to role 'admin'"
        app.sqlClient.query().
          insert('role_groups',
            ['id', 'role_id', 'group_id'],
            [1, 1, 1]
          ).execute (err, result) ->
            if err
              console.log 'ERROR assigning group to role: ' + err
            else if result
              console.log 'Role assigment created with id: %s', result.id
    )
)
app.sqlClient.connect()