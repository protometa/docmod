###

DOCMOD

require path from src (may be json, js, or coffee)
may be function that accepts req for dynamic content
may return promise for async results
resolves to object of document meta
view is specified in meta
"load" fields are loaded into meta obj
	.txt, .html, .md are encoded as utf8, otherwise base64 ...uh there will be others like .jade
"link" fields are resolved as relative url paths in meta obj
	maybe only copy linked things to /out, also render if necessary
	or run static on src after docmod /!\

route view's locals are merged and rendered
if view contains layout it's rendered in that view and so on...

if require fails with module not found err, proceed without err
serve static from src after docmod

###

url = require 'url'
fs = require 'fs'
p = require 'path'
doc = require './doc'
async = require 'async'
Q = require 'q'
jade = require 'jade'
md = require 'marked'
require 'uber'

module.exports = (opt) ->

	# inherit defaults
	opt.uber
		src: './src'
		out: './out'
		maxDepth: 4

	return (req, res, next) ->

		get = (path) ->
			d = Q.defer()
			try
				# meta may be json (static), js, or coffee
				meta = require( path )

			catch err
				# console.log err
				d.reject(err)
				return d.promise

			locals = {}.uber(meta)

			# console.log locals
					

			# meta props may be functions that accept req (dynamic)
			for key,prop of locals
				if typeof prop == 'function'
					locals[key] = prop(req)

			# meta props may be or return promises (asynchronous)
			# props = []
			# for key,prop of meta
			# 	# console.log key,prop
				
			# 	meta[key] = Q.when(prop).then (prop) ->
			# 		console.log key, prop
			# 		meta[key] = prop

			# 	props.push meta[key]


			async.each Object.keys(locals), (key, cont) ->
				
				locals[key] = Q.when( locals[key] )
				.then (prop) ->
					locals[key] = prop
					cont()

				.fail (err) ->
					cont(err)

			, (err) ->
				if err
					return d.reject(err)


				# load files...

				if locals.load?
					async.each Object.keys(locals.load), (key,cont) ->
						file = locals.load[key]

						ext = p.extname(file)

						switch ext
							when '.jpg','.png','.gif'
								encode = 'base64'
							else
								encode = 'utf8'

						file = p.resolve( path, file )

						fs.readFile file, {encoding: encode}, (err, data) ->
							if err then return cont(err)

							# if ext == '.md'
							# 	data = md( data )

							# 	meta[key] = data
							# 	cb()

							locals[key] = data
							cont()

					, (err) ->
						if err then return d.reject(err)

						delete locals.load

						d.resolve(locals)

				else
					d.resolve(locals)
  
			# .fail (err) ->
			# 	d.reject(err)
			# .done()

			return d.promise


		layout = (locals) ->

			locals.content ?= locals.body

			# console.log locals

			srcPath = p.resolve('.', p.join( opt.src,'layouts', locals.layout) )

			return get( srcPath )
			.then (meta) ->

				# console.log 'layout:', meta

				delete locals.layout

				locals.uber(meta)

				if locals.template?
					return render(locals)
				else
					return locals


		render = (locals) -> 
			return Q.nfcall( jade.render, locals.template, locals )
			.then (rendered) ->
				locals.content = rendered
				delete locals.template
				return locals


		# console.log url.parse(req.url)

		srcPath = p.resolve('.',p.join( opt.src,'docs',url.parse(req.url).pathname))

		# console.log srcPath			

		docMeta = null
		layoutMeta = null
		locals = {}
		i = 0

		get( srcPath ) # get doc meta
		.then (meta) ->

			locals.uber(meta)
			locals.url = url.parse(req.url).pathname

			# use md in body
			if locals.body?
				locals.body = md( locals.body )

			if locals.template?
				return render(locals)
			else
				return locals

		.then loopLayout = (locals) ->

			# console.log locals

			i++

			# console.log 'loop:', i, opt.maxDepth

			if i > opt.maxDepth
				throw new Error('Max layout depth exceeded')

			# console.log 'loop'
			Q.when(locals).then (locals) ->

				# console.log 'locals:', locals

				if locals.layout?

					return loopLayout( layout(locals) )

				else
					return locals

		.then (locals) ->

			locals.uber( opt.locals )

			# console.log 'final:',locals

			if locals.content?
				res.send( locals.content )

			else
				res.send( locals )



		.fail (err) ->

			console.log err			

			if err.code == 'MODULE_NOT_FOUND'
				next()
			else
				next(err)

		.done()




