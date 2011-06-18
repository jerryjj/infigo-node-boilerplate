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
funk = require('funk')()

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

db = require('db-mysql')[app.set('db_type')].Database
app.sqlClient = new db(
  hostname: app.set 'db_host'
  port: app.set 'db_port'
  database: app.set 'db_name'
  user: app.set 'db_user'
  password: app.set 'db_pass'  
).on('error', (error) ->
  console.log 'ERROR connecting to SQL server: ' + error
).on('ready', (server) ->
  console.log 'MySQL connected to ' + server.hostname + ' (' + server.version + ')'
)
app.sqlClient.connect funk.add (err) ->
  if err
    return

app.configure () ->
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.set 'view options', layout: 'layout.jade'
  app.use express.favicon()
  app.use connect.bodyParser()
  app.use express.cookieParser()
  app.use express.session(cookie: {maxAge: 2 * (24 * 60 * 60 * 1000)}, secret: global.config.cookie_secret)
  app.use express.logger(format: '\x1b[1m:method\x1b[0m \x1b[33m:url\x1b[0m :response-time ms')
  app.use express.methodOverride()
  app.use connect.static(__dirname + '/static')
  app.use app.router

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

###
  Authentication related
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

  req.app.sqlClient.query().
    select('*').
    from('users').
    where('username = ?', [req.body.user.username]).
    execute (err, rows, cols) ->
      if !err && rows.length >= 1
        pwd_hash = Auth.createHashedPassword(rows[0].salt, req.body.user.password)
        
        req.app.sqlClient.query().
          select('id').
          from('users').
          where('username = ?', [req.body.user.username]).
          and('hashed_password = ?', [pwd_hash]).
          execute (err, prows, pcols) ->
            if err || prows.length < 1
              req.flash 'error', 'Incorrect credentials'
              res.redirect '/auth/login?redirect_to=' + redirect_to
            else
              req.session.user_id = prows[0].id
              app.sqlClient.query().update('users').
                set({'last_login': dateFormat(new Date, 'yyyy-mm-dd HH:MM:ss')}).
                where('id = ?', [prows[0].id]).
                execute (err, rows, cols) ->
                  if err
                    console.log 'error updating last login'
                    console.log err
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
    dialect.sync {interval: 60 * 1000}, () ->
    app.listen port
    console.log 'Express server listening on port %d, environment: %s', app.address().port, app.settings.env  
    console.log 'Using connect %s, Express %s', connect.version, express.version
    console.log 'Http Listening on http://0.0.0.0:' + port
    return
  return
