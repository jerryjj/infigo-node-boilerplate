_ = require 'underscore'
mongoose = require 'mongoose'
winston = require 'winston'
logger = new winston.Logger {
  transports: [
    new winston.transports.Console { handleExceptions:true}
    new winston.transports.File { filename: 'all-logs.log', handleExceptions:true}
  ]
}


User = mongoose.model 'User'
Group = mongoose.model 'Group'
Role = mongoose.model 'Role'
LoginToken = mongoose.model 'LoginToken'
GroupUser = mongoose.model 'GroupUser'
RoleGroup = mongoose.model 'RoleGroup'

class UgrManager
  constructor: () ->
    return

  listUser: (user, next) ->
    User.findOne username:user, (err,docs) ->
      next err,docs

  listGroup: (group, next) ->
    Group.findOne name:group, (err,docs) ->
      next err,docs

  listRole: (role, next) ->
    Role.findOne name:role, (err,docs) ->
      next err,docs

  deleteRole: (r, next)->
    Role.findOne name:r, (err, role)->
      if !role
        logger.info "no role #{r}"
        next err
      else
        Role.remove name:r, (err)->
          if err
            logger.debug 'error on delete role', name:r, role:role, err:err
          else
            logger.info "deleted role #{r}"
          next err

  deleteGroup: (g, next)->
    Group.findOne name:g, (err, group)->
      if !group
        logger.info "no group #{g}"
        next err
      else
        # remove group from role
        Role.find {}, (err, docs)->
          asyncGroupRemove = _.after docs.length, ()->
            # remove group
            Group.remove name:g, (err)->
              if err
                logger.debug 'error on delete group', g:g, group:group, err:err
              else
                logger.info "deleted group #{g}"
              next err
          _.each docs, (role)->
            rg = role.getRoleGroup group._id
            if rg
              role.groups.id(rg._id).remove()
              role.save (err)->
                if err
                  logger.debug 'error on remove rg', g:g, role:role, err:err
                else
                  logger.info "removed #{rg.name} from role #{role.name}"
                asyncGroupRemove()
            else
              asyncGroupRemove()
  # user
  deleteUser: (u, next) ->
    User.findOne username:u, (err,user)->
      if not user
        logger.info "no user #{u}"
        next err
      else
        # remove user from group
        Group.find {}, (err,docs)->
          asyncUserRemove = _.after docs.length, ()->
            # remove user
            User.remove username:u, (err)->
              if err
                logger.debug 'error on delete user', u:u, err:err
              else
                logger.info "deleted user #{u}"
              next err
          _.each docs, (group)->
            gu = group.getGroupUser user._id
            if gu
              group.users.id(gu._id).remove()
              group.save (err)->
                if err
                  logger.debug 'error on remove gu', u:u, group:group, err:err
                else
                  logger.info "removed #{u} from group #{group.name}"
                asyncUserRemove()
            else
              asyncUserRemove()


  updateUserWithPassword: (u, pwd, next) ->
    User.findOne username:u, (err,user)->
      # create new user if not exist
      if not user
        user = new User username: u
        logger.info 'to create new user: ' + u
      user.password = pwd + ''
      user.save (err)->
        if err
          logger.debug 'error on save user', username:u, user:user, err:err
        else
          logger.info "saved user #{u}"
        next err, user

  # role
  createRoleUnlessExist: (r, next) ->
    Role.findOne name:r, (err, role) ->
      if not role
        role = new Role name:r
        logger.info "to create new role #{r}"
        role.save (err) ->
          if err
            logger.debug 'error on save role', name:r, role:role, err:err
          else
            logger.info "created new role #{r}"
          next err, role
      else
        next null, role

  addGroupToRole: (g,role, next)->
    Group.findOne name:g, (err, group)->
      if not group
        logger.info "no group #{g}"
        next err
      else
        if role.hasGroup(group._id)
          logger.info "group #{g} already in role #{role.name}"
          next err
        else
          role.groups.push new RoleGroup {
            group_id: group.id
            name: group.name
          }
          role.save (err,group) ->
            if err
              logger.debug 'error on add group to role', g:g, role:role, err:err
            else
              logger.info "added group #{g} to role #{role.name}"
            next err

  removeGroupFromRole: (g, role, next)->
    Group.findOne name:g, (err, group)->
      if not group
        logger.info "no group #{g}"
        next err
      else
        rg = role.getRoleGroup group._id
        if not rg
          logger.info "group #{g} not in role #{role.name}"
          next err
        else
          role.groups.id(rg._id).remove()
          role.save (err, role)->
            if err
              logger.debug 'error on remove group from role', g:g, role:role, err:err
              next err
            else
              logger.info "removed group #{g} from role #{role.name}"
              next err

  # group
  createGroupUnlessExist: (g, next) ->
    Group.findOne name:g, (err,group) ->
      if !group
        group = new Group name:g
        logger.info "to create new group #{g}"
        group.save (err)->
          if err
            logger.debug 'error on save group', name:g, group:group, err:err
          else
            logger.info "created new group #{g}"
          next err, group
      else
        next null, group


  addUserToGroup: (u, group, next)->
    User.findOne username:u, (err,user)->
      if !user
        logger.info "no user #{u}"
        next err
      else
        if group.hasUser(user._id)
          logger.info "user #{u} already in group #{group.name}"
          next err
        else
          group.users.push new GroupUser {
            user_id: user.id
            username: user.username
          }
          group.save (err, group) ->
            if err
              logger.debug 'error on add user to group', u:u, group:group, err:err
              next err
            else
              logger.info "added user #{u} to group #{group.name}"
              next err
  
  removeUserFromGroup: (u, group, next) ->
    User.findOne username:u, (err,user)->
      if !user
        logger.info "no user #{u}"
        next err
      else
        gu = group.getGroupUser user._id
        if !gu
          logger.info "user #{u} not in group #{group.name}"
          next err
        else
          group.users.id(gu._id).remove()
          group.save (err, group) ->
            if err
              logger.debug 'error on remove user from group', u:u, group:group, err:err
              next err
            else
              logger.info "removed user #{u} from group #{group.name}"
              next err


module.exports = new UgrManager()
