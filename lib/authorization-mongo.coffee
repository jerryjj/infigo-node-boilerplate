mongoose = require 'mongoose'

User = mongoose.model 'User'
Group = mongoose.model 'Group'
Role = mongoose.model 'Role'
LoginToken = mongoose.model 'LoginToken'  

_checkRoleByName = (name) ->
  Role.findOne {name: name}, (err, role) ->
    if err || !role
      r = new Role name: name
      r.save()
  return

class Authorization
  constructor: () ->
    return

  checkLogin: (req, res, next) ->
    if req.session.user_id
      User.findById req.session.user_id, (err, user) ->
        if user
          req.currentUser = user
          next()
    else if req.cookies.logintoken    
      @_authenticateFromLoginToken req, res, next
    else
      next()

  requireLogin: (req, res, next) ->
    url = require('url').parse req.url, true    
    redirect_to = require('querystring').stringify(redirect_to: url.href)
    
    if req.session.user_id
      User.findById req.session.user_id, (err, user) ->
        if user
          req.currentUser = user
          next()
        else
          if req.xhr
            res.redirect '/auth/login', 401
          else
            res.redirect '/auth/login?' + redirect_to
    else if req.cookies.logintoken    
      @_authenticateFromLoginToken req, res, next
    else
      if req.xhr
        res.redirect '/auth/login', 401
      else
        res.redirect '/auth/login?' + redirect_to

  requireRole: (names) ->     
    return (req, res, next) =>
      role_names = names.split(' ')      
      
      for name in role_names
        _checkRoleByName name
      
      @requireLogin req, res, () ->
        req.currentUser.hasRoles(role_names, (tot) ->
          #console.log '%s / %s', tot, role_keys.length
          if tot >= role_names.length            
            return next()
          else
            return res.redirect '/403'
        )
    
  _authenticateFromLoginToken = (req, res, next) ->
    cookie = JSON.parse req.cookies.logintoken
    url = require('url').parse req.url, true    
    redirect_to = require('querystring').stringify(redirect_to: url.href)
    
    LoginToken.findOne username: cookie.username, series: cookie.series, token: cookie.token, (err, token) ->
      if !token
        if req.xhr
          res.redirect '/auth/login', 401
        else
          res.redirect '/auth/login?' + redirect_to

      User.findOne username: token.username, (err, user) ->    
        if !user
          if req.xhr
            res.redirect '/auth/login', 401
          else
            res.redirect '/auth/login?' + redirect_to
        else
          req.session.user_id = user.id
          req.currentUser = user

          token.token = token.randomToken()
          token.save () ->
            res.cookie 'logintoken', token.cookieValue, expires: new Date(Date.now() + 2 * 604800000), path: '/'
            next()        
    

module.exports = new Authorization()