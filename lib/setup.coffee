###
Setup.js created by Ben Weaver (http://gist.github.com/508314)
Coffee-Scripted by Jerry Jalava
###

fs = require 'fs'
path = require 'path'

# --- Methods

run = require

# A shortcut for adding `lib' and `ext' subfolders, then running a
# main program.
app = (base, main) ->
  lib path.join(base, 'lib')
  ext path.join(base, 'ext')
  
  if main
    return run path.join(base, main)
  
  return exports

# Local libraries
lib = (folder) ->
  if exists folder
    require.paths.unshift folder
  return exports

# Third-party libraries
ext = (folder) ->
  if !exists folder
    return exports

  # Some programmers refer to third-party libraries in a fully-qualified manner.
  require.paths.unshift folder

  fs.readdirSync(folder).forEach (name) ->
    base = path.join folder, name
    linked = false

    # Pure-JS packages have a `lib' folder with LIBRARY.js files in it.
    # Packages with C++ bindings will have a `build/default' folder
    # with LIBRARY.node files in it after running node-waf.
    [path.join(base, '/build/default'), path.join(base, '/lib')]
      .forEach (folder) ->
        if exists folder
          require.paths.unshift folder
          linked = true
          return

    # If neither `lib' or `build' were found, fallback to linking the
    # folder itself.
    if !linked
      require.paths.unshift base
      return
  
  return exports

# --- Aux

exists = (filename) ->
  try
    fs.statSync filename
    return true
  catch x
    return false
    
exports.app = app
exports.lib = lib
exports.ext = ext
exports.run = run