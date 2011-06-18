Auth = require 'authorization'

module.exports = (app) ->
  # index route
  app.get '/admin', Auth.requireRole('admin'), (req, res) -> 
    
    res.render 'admin/index',      
      app.adminCommonLocals req