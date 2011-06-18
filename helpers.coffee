class FlashMessage
  constructor: (@type, @messages) ->
    if typeof @messages == 'string'
      @messages = [@messages]
  
  icon: () ->
    switch @type
      when 'info' then 'ui-icon-info'
      when 'error' then 'ui-icon-alert'
  
  stateClass: () ->
    switch @type
      when 'info' then 'ui-state-highlight'
      when 'error' then 'ui-state-error'
  
  toHTML: () ->
    '<div class="ui-widget flash">' +
    '<div class="' + @stateClass() + ' ui-corner-all">' +
    '<p><span class="ui-icon ' + @icon() + '"></span>' + @messages.join(', ') + '</p>' +
    '</div></div>'

exports.dynamicHelpers =
  flashMessages: (req, res) ->
    html = ''
    ['error', 'info'].forEach (type) ->
      messages = req.flash type
      if messages.length > 0
        html += new FlashMessage(type, messages).toHTML()
    return html

exports.helpers = (app, options) ->
  return {
    appName: 'Valtra'
    version: '0.0.1'

    nameAndVersion: (name, version) ->
      name + ' v' + version

    truncate: (str, num) ->
      limit = num || 20

      if str && str.length > limit
        return str.slice(0, limit) + '...'
      else
        return str
    dateFormat: require('dateformat')
  }

exports.range = (low, high, step) ->
    matrix = []
    walker = 1 unless step
    chars = false
    inival = endval = plus = null

    if !isNaN(low) && !isNaN(high)
      inival = low
      endval = high
    else if isNaN(low) && isNaN(high)
      chars = true
      inival = low.charCodeAt(0)
      endval = high.charCodeAt(0)
    else
      inival = (isNaN(low) ? 0 : low)
      endval = (isNaN(high) ? 0 : high)

    plus = !(inival > endval)

    if plus
      tmp = while inival <= endval
        if chars
          matrix.push(String.fromCharCode(inival))
        else      
          matrix.push(inival)
        inival += walker
    else
      tmp = while inival >= endval
        if chars
          matrix.push(String.fromCharCode(inival))
        else
          matrix.push(inival)
        inival -= walker

    return matrix