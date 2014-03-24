
p = require 'path'
u = require 'url'

yaml = require 'js-yaml'


module.exports = (req,arg) ->
	opt = {}
	if typeof arg == 'string'
		opt.url = arg
	else
		opt = arg

	requrl = u.parse(req.url)
	opturl = u.parse(opt.url)
	reqpath = opt.url

	if !opturl.hostname?

		if opturl.pathname[0] is '/'
			reqpath = opt.url
		else
			reqpath = p.join( requrl.pathname, opt.url )

	return reqpath



module.exports = Linker










