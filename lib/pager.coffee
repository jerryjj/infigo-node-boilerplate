_url = require 'url'
_querystring = require 'querystring'

class Pager
  @prefix = "pager_"
  
  constructor: (@req, @id, @limit) ->
    @max = 0
    @vals = 
      page: 1
      start: 0
      end: @limit
      max: @max
    return
  
  setMax: (@max) ->
    return
  
  values: () ->    
    url = _url.parse @req.url, true
    @vals.max = @max
    
    if !url.query
      return @vals
    
    if url.query[@_getPageVarName()]
      @vals.page = Number url.query[@_getPageVarName()]
    
    @vals.start = (@vals.page * @limit) - @limit
    @vals.end = @vals.start + @limit
    if @max >0 && @vals.end > @max
      @vals.end = @max
    
    return @vals
  
  pages: () ->
    pageCnt = Math.round(@max / @limit)
    if pageCnt == 0
      pageCnt = 1
    
    pages = ({type: 'page', val: page, url: @_pageUrl(page), active: (@vals.page == page)} for page in [1..pageCnt])
    beg = []
    if @vals.page > 1
      beg = [{type: 'nav', val: 'first', url: @_pageUrl(1), active: false}]
    if @vals.page >= 2
      beg = beg.concat([{type: 'nav', val: 'prev', url: @_pageUrl(@vals.page-1), active: false}])
      
    end = []
    if @vals.page < pageCnt
      end = [{type: 'nav', val: 'last', url: @_pageUrl(pageCnt), active: false}]
    if @vals.page <= pageCnt-1
      end = [{type: 'nav', val: 'next', url: @_pageUrl(@vals.page+1), active: false}].concat(end)
    
    tmp = beg.concat(pages)
    tmp = tmp.concat(end)
    
    return tmp
  
  _pageUrl: (page) ->
    url = _url.parse @req.url, true
    url.query[@_getPageVarName()] = page
    return url.pathname + '?' + _querystring.stringify(url.query)
  
  _getPageVarName: () ->
    return Pager.prefix + @id + '_page'
    
module.exports = (req, id, limit) ->
  return new Pager(req, id, limit)