crypto = require('crypto')
CoffeeScript = require 'coffee-script'
dateFormat = require 'dateformat'
async = require('async')
_ = require('underscore')

toLower = (v) ->
  v.toLowerCase()

validatePresenceOf = (value) ->
  value && value.length

defineModels = (mongoose, next) ->
  Schema = mongoose.Schema
  ObjectId = Schema.ObjectId
  
  ###
  Model: User
  ###

  User = new Schema
    username:
      type: String
      validate: [validatePresenceOf, 'username is required']
      index:
        unique: true
    email:
      type: String
      validate: [validatePresenceOf, 'email is required']
      index: true
    name:
      first:
        type: String
        default: ""
      last:
        type: String
        default: ""
    hashed_password: String
    salt: String
    # roles: [String]
    # groups: [String]

  User.virtual('id').get () ->
    this._id.toHexString()

  User.virtual('name.full').get () ->
    return this.name.first + " " + this.name.last
    
  User.virtual('name.initials').get () ->
    initials = String(this.name.first).substr(0,1) + String(this.name.last).substr(0,1)
    initials = initials.toUpperCase()
    return initials

  User.virtual('password').set (password) ->
    this._password = password
    this.salt = this.makeSalt()
    this.hashed_password = this.encryptPassword password
  .get () -> this._password

  User.method 'authenticate', (plainText) ->
    this.encryptPassword(plainText) is this.hashed_password
  
  User.method 'makeSalt', () ->
    Math.round(new Date().valueOf() * Math.random()) + ''

  User.method 'encryptPassword', (password) ->
    crypto.createHmac('sha1', this.salt).update(password).digest('hex')

  User.pre 'save', (next) ->
    if !validatePresenceOf this.hashed_password
      next new Error('Invalid password')
    else
      next()
      
  User.method 'hasRoles', (roles, next) ->
    Role = mongoose.model 'Role'
    Group = mongoose.model 'Group'
    
    tasks = []
    user_id = this._id
    
    for rk in roles
      do (rk) ->
        tasks.push (cb) ->
          Role.findOne {name: rk}, (err, role) ->
            if err || !role
              return cb(null, 0)
            if role.hasUser user_id
              cb(null, 1)
            else if role.groups.length > 0
              async.forEach role.groups, (grp, cbb) ->
                Group.findOne {_id: grp.group_id}, (e, group) ->
                  if group && group.hasUser user_id
                    return cbb()
                  else
                    return cbb(0)
              , (e, r) ->
                if e
                  cb(null, 0)
                else
                  cb(null, 1)
            else
              cb(null, 0)
    
    async.series tasks, (err, results) ->
      tot = 0
      for r in results
        tot += r
      next(tot)
  
  ###
  Model: GroupUser
  ###
  GroupUser = new Schema
    user_id: ObjectId
    username: String

  ###
  Model: Groups
  ###
  Group = new Schema
    name:
      type: String
      validate: [validatePresenceOf, 'name is required']
      index:
        unique: true
    users: [GroupUser]

  Group.method 'hasUser', (user_id) ->
    for user in this.users
      if user.user_id.toString() == user_id.toString()
        return true
    return false

  Group.method 'getGroupUser', (user_id) ->
    _.detect this.users, (user)->
      user.user_id.toString() == user_id.toString()

  ###
  Model: RoleGroup
  ###
  RoleGroup = new Schema
    group_id: ObjectId
    name: String
    
  ###
  Model: RoleUser
  ###
  RoleUser = new Schema
    user_id: ObjectId
    username: String
    name:
      first: String
      last: String
      full: String
  
  ###
  Model: Role
  ###
  Role = new Schema
    name:
      type: String
      validate: [validatePresenceOf, 'role name is required']
      index:
        unique: true
      set: toLower
    groups: [RoleGroup]
    users: [RoleUser]

  Role.method 'getRoleGroup', (group_id)->
    _.detect this.groups, (group)->
      group.group_id.toString() == group_id.toString()

  Role.method 'hasGroup', (group_id) ->
    for grp in this.groups
      if grp.group_id.toString() == group_id.toString()
        return true
    return false

  Role.method 'hasUser', (user_id) ->
    for user in this.users
      if user.user_id.toString() == user_id.toString()
        return true
    return false
  
  ###
  Model: LoginToken
  Used for session persistence.
  ###
  LoginToken = new Schema
    username:
      type: String
      index: true
    series:
      type: String
      index: true
    token:
      type: String
      index: true

  LoginToken.method 'randomToken', () ->
    Math.round (new Date().valueOf() * Math.random()) + ''

  LoginToken.pre 'save', (next) ->
    #Automatically create the tokens
    this.token = this.randomToken()
    if this.isNew
      this.series = this.randomToken()
    next()

  LoginToken.virtual('id').get () ->
    this._id.toHexString()

  LoginToken.virtual('cookieValue').get () ->
    JSON.stringify username: this.username, token: this.token, series: this.series

  mongoose.model 'User', User
  mongoose.model 'Group', Group
  mongoose.model 'Role', Role
  mongoose.model 'GroupUser', GroupUser
  mongoose.model 'RoleGroup', RoleGroup
  mongoose.model 'RoleUser', RoleUser
  mongoose.model 'LoginToken', LoginToken
  
  next()
  
exports.defineModels = defineModels
