###

	docpad async fsdb middleware
	set src, out, and config


	if req path matches doc in src/docs
		if doc is not registered as static
			render doc to out
				wrap and set async helpers <- do this on init
					wrapper registers call with render and returns token
				render based on extentions
				on results from registered function
					replace tokens with results (handlebars?)
					serve result

			if dynamic not set to true
				register doc as static
			else render and serve doc

		serve matching doc in out

###

url = require 'url'

module.exports = (opt) ->

	src = opt.src ? '/src'
	out = opt.out ? '/out'



	return  (req, res, next) ->

		if ('GET' != req.method && 'HEAD' != req.method) then return next()


		req.url

		next() # :)






