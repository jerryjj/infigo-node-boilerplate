###
Setup Dependencies
###
require.paths.unshift __dirname
s = require __dirname + "/lib/setup"
s.ext __dirname + "/lib"
s.ext __dirname + "/support"

sys = require 'sys'
connect = require 'connect'
express = require 'express'
CoffeeScript = require 'coffee-script'
mongoose = require 'mongoose'
mongoStore = require 'connect-mongodb'
funk = require('funk')()
models = require './models'
dateFormat = require 'dateformat'

port = process.env.PORT || 8081

app = module.exports = express.createServer()

app.helpers(require('./helpers').helpers(app, {}))
app.dynamicHelpers(require('./helpers').dynamicHelpers)

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

app.configure () ->
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.set 'view options', layout: 'layout.jade'
  app.use express.favicon()
  app.use connect.bodyParser()
  app.use express.cookieParser()
  app.use express.session(cookie: {maxAge: 2 * (24 * 60 * 60 * 1000)}, store: mongoStore(url: app.set('db-uri'), reapInterval: 60 * 1000), secret: global.config.cookie_secret)
  app.use express.logger(format: '\x1b[1m:method\x1b[0m \x1b[33m:url\x1b[0m :response-time ms')
  app.use express.methodOverride()
  app.use connect.static(__dirname + '/static')
  app.use app.router

###
Setup models
###

User = Group = Role = LoginToken = db = null
  
models.defineModels mongoose, funk.add () ->
  db = mongoose.connect app.set('db-uri')
  
  app.User = User = mongoose.model 'User'
  app.Group = Group = mongoose.model 'Group'
  app.Role = Role = mongoose.model 'Role'
  app.LoginToken = LoginToken = mongoose.model 'LoginToken'

###
setup the errors
###

app.error (err, req, res, next) ->  
  if err instanceof NotFound
    res.render '404.jade',
    status: 404
    layout: false
    locals:
      title : '404 - Not Found'
  else
    next err

if app.settings.env == 'production'
  app.error (err, req, res) ->
    res.render '500.jade',
    status: 500
    layout: false
    locals:
      error: err

###
Routes
###

app.authLocals = (req) ->
  return {
    hasUser: !(req.currentUser is null)
    user: req.currentUser || {}
  }

app.commonLocals = (req, ext) ->
  if not ext
    ext = {}
  
  common =
    locals:
      title : 'Project'
      analyticssiteid: ''
      auth: app.authLocals(req)
      inAdmin: false
  
  return CoffeeScript.helpers.merge common, ext

app.adminCommonLocals = (req, ext) ->
  if not ext
    ext = {}

  common = app.commonLocals(req, 
    layout: 'admin/layout.jade'
    locals:
      title : 'Project :: Admin'
      inAdmin: true
  )
  
  app.commonLocals req, CoffeeScript.helpers.merge common, ext

# Auth routes

Auth = require 'authorization'

## Login route
app.get '/auth/login', (req, res) ->
  res.render 'auth/login',
    app.commonLocals(req,
      locals:
        auth:
          hasUser: false
    )

## Process Login route
app.post '/auth/login', (req, res) ->  
  url = require('url').parse req.url, true  
  
  redirect_to = '/'
  if url.query && url.query.redirect_to
    redirect_to = url.query.redirect_to

  User.findOne username: req.body.user.username, (err, user) ->
    if user && user.authenticate req.body.user.password
      req.session.user_id = user.id
      if req.body.remember_me
        loginToken = new LoginToken username: user.username
        loginToken.save () ->
          res.cookie 'logintoken', loginToken.cookieValue, expires: new Date(Date.now() + 2 * 604800000), path: '/'
          res.redirect redirect_to
      else
        res.redirect redirect_to
    else
      req.flash 'error', 'Incorrect credentials'
      res.redirect '/auth/login?redirect_to=' + redirect_to

## Logout route
app.get '/auth/logout', Auth.requireLogin, (req, res) ->
  if req.session
    req.session.destroy () -> return
  res.redirect '/'

# Index route
app.get '/', (req, res) ->
  res.render 'index',
    app.commonLocals req

# Load additional routes here

require('./routes/admin/index')(app)

# A Route for Creating a 500 Error (Useful to keep around)
app.get '/500', (req, res) ->
  throw new Error 'An expected error'

# The 404 Route (ALWAYS Keep this as the last route)
app.get '/*', (req, res) ->
  throw new NotFound

NotFound = (msg) ->
  this.name = 'NotFound'
  Error.call this, msg
  Error.captureStackTrace this, arguments.callee
sys.inherits NotFound, Error

if !module.parent
  funk.parallel () ->
    app.listen port
    console.log 'Express server listening on port %d, environment: %s', app.address().port, app.settings.env  
    console.log 'Using connect %s, Express %s', connect.version, express.version
    console.log 'Http Listening on http://0.0.0.0:' + port
    return
  return
