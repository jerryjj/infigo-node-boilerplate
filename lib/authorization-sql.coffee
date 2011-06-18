crypto = require 'crypto'

_checkRoleByName = (app, name) ->
  app.sqlClient.query().
    select('id').
    from('roles').
    where('name = ?', [name]).
    execute (err, rows, cols) ->
      if err || (rows && rows.length < 1)
        app.sqlClient.query().
          insert('roles',
            ['name'],
            [name]
          ).execute (err, result) ->
            if err
              console.log err
        return
      return
  return

class Authorization
  constructor: () ->
    return

  checkLogin: (req, res, next) ->    
    if req.session.user_id
      req.app.sqlClient.query().
        select('*').
        from('users').
        where('id = ?', [req.session.user_id]).
        execute (err, rows, cols) ->
          if err || rows.length < 1
            return next()          
          req.currentUser = rows[0]
          next()
    else
      next()

  requireLogin: (req, res, next) ->
    url = require('url').parse req.url, true
    redirect_to = require('querystring').stringify(redirect_to: url.href)

    if req.session.user_id
      req.app.sqlClient.query().
        select('*').
        from('users').
        where('id = ?', [req.session.user_id]).
        execute (err, rows, cols) ->
          if err || rows.length < 1
            return next()          
          req.currentUser = rows[0]
          next()
    else
      if req.xhr
        res.redirect '/auth/login', 401
      else
        res.redirect '/auth/login?' + redirect_to

  requireRole: (names) ->
    return (req, res, next) =>    
      role_names = names.split(' ')      

      for name in role_names
        _checkRoleByName req.app, name
      
      @requireLogin req, res, () ->            
        #TODO: implement like in mongo
        
        # 1. check if user has role
        # 2. check if user groups has role
        # 3. compare role_keys length with matched length
        next()
  
  makeSalt: () ->
    salt = Math.round(new Date().valueOf() * Math.random()) + ''
    return salt
  
  createHashedPassword: (salt, plaintext) ->
    return crypto.createHmac('sha1', salt).update(plaintext).digest('hex')
  
  createUser: (app, data, next) ->
    User =
      firstname:''
      lastname:''
      username:''
      email:''
      salt:''
      password:''
      hashed_password:''

    for key, value of data
      if value
        User[key] = value

    User.salt = @makeSalt()
    if User.password
      User.hashed_password = @createHashedPassword(User.salt, User.password)    
    
    app.sqlClient.query().
      insert('users',
        ['firstname', 'lastname', 'username', 'salt', 'hashed_password', 'email'],
        [User.firstname, User.lastname, User.username, User.salt, User.hashed_password, User.email]
      ).execute (err, result) ->
        if err
          console.log 'ERROR: ' + err
          throw err
        console.log 'User created with id: %s', result.id
        next(result)

  updateUser: (app, data, next) ->
    User =
      id:0
      firstname:''
      lastname:''
      username:''
      email:''
      salt:''
      password:''
      hashed_password:''

    for key, value of data
      if value
        User[key] = value

    if User.id != 0
      if User.password != ''
        @updateUserPassword(app, data)
    
      app.sqlClient.query().
        update('users').
        set({'firstname':User.firstname, 'lastname':User.lastname, 'username':User.username, 'email':User.email}).
        where('id = ?',[User.id]).
        execute (err, result) ->
          if err
            console.log 'ERROR: ' + err
            throw err
          console.log 'User updated with id: %s', User.id

          next(User)
    else
      next()

  updateUserPassword: (app, data, next) ->
    User =
      id:0
      password:''
      hashed_password:''
      salt:''

    for key, value of data
      if value
        User[key] = value

    if User.password != '' && User.id != 0

      User.salt = @makeSalt()
      User.hashed_password = @createHashedPassword(User.salt, User.password)
      app.sqlClient.query().
        update('users').
        set({'salt':User.salt, 'hashed_password':User.hashed_password}).
        where('id = ?',[User.id]).
        execute (err, result) ->
          if err
            console.log 'ERROR: ' + err
            throw err
          console.log 'User password updated with id: %s', User.id
  
  generatePassword: (length, seed, lower_only) ->
    range = require('helpers').range
    _ = require 'static/js/underscore'
    
    chars = 0
    decimal = 0
    pwd = ''
    length = 7 unless length
    seed = false unless seed
    lower_only = false unless lower_only
        
    character_table = range('a','z')
    if !lower_only
      character_table = character_table.concat(range('A','Z'))
    character_table = character_table.concat(range(0,9))    
    character_table = _.without(character_table, 'I', 'l', 'o', 'O', '0')
    ctable_length = character_table.length
    
    tmp = while chars < length
      if seed == false
        seed = ""+(new Date()).getTime()
      
      hash = crypto.createHash('md5').update(seed).digest('hex')
      
      i = 0
      tmp = while (chars < length) && i < 32
        ++chars
        i += 2
        
        hex_string = (hash.substr(i, 32)).replace(/[^a-f0-9]/gi, '')
        decimal = parseInt hex_string, 16
        char = character_table[(decimal % ctable_length)]
        pwd += char
        
      seed = false
    
    return pwd

module.exports = new Authorization()