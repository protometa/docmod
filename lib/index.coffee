###

DOCMOD

load path from src with indexing on 'index.yaml'
	append '.yaml' to url and open, if err then append '/index.yaml' and open

parse yaml with link and load constructors
	resolve links and loads
		load
			if relative file
				resolve from current dir stream current request
			if absolute file
				resolve to src dir and stream current request
			if full url
				stream current request

		request?
			if obj
				treat as options for request and send

		link
			if relative file
				resolve to current dir

render body with template and locals
	treat body as markdown
	template is jade for now
	put result in 'content'
	delete template and body

load layout and uber layout locals
	render...
	repeat for remaining layouts

uber site locals
if content send content or send json obj



# old...

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

fs = require 'fs'
strm = require 'stream'
p = require 'path'
u = require 'url'
util = require 'util'
yaml = require 'js-yaml'
request = require 'request'
async = require 'async'
Q = require 'q'
jade = require 'jade'
md = require 'marked'
require 'uber'

Loader = require './loader'
Linker = require './linker'

DOC_SCHEMA = yaml.Schema.create([ Loader.yamlType, Linker.yamlType ])



module.exports = (opt) ->

	# inherit defaults
	@opt = opt.uber
		src: './src'
		out: './out'
		maxDepth: 4

	return (req, res, next) ->

		url = u.parse(req.url)

		get = (path) ->

			d = Q.defer()

			trypath = path + '.yaml'

			try
				doc = yaml.safeLoad(fs.readFileSync( trypath, 'utf8'),{ schema: DOC_SCHEMA })
				d.resolve doc

			catch err

				if err.code is 'ENOENT'
					trypath = p.join path, 'index.yaml'

					try
						doc = yaml.safeLoad(fs.readFileSync( trypath, 'utf8'),{ schema: DOC_SCHEMA })
						d.resolve doc

					catch err
						d.reject err

				else
					d.reject err

			return d.promise


		get0 = (path) ->
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

		linkAndLoad = (locals, path) ->

			d = Q.defer()

			async.each Object.keys(locals), (key, cont) ->

				prop = locals[key]

				# debugger

				if prop instanceof Linker
					locals[key] = prop.resolve(req, path)

					cont()

				else if prop instanceof Loader

					newProp = ''

					prop.resolve(req, path)
					.on 'data', (data) ->
						newProp += data

					.on 'end', ->

						locals[key] = newProp.toString()

						cont()

					.on 'error', cont

				else if typeof prop is 'object'

					# debugger

					linkAndLoad( prop, path )
					.then ->
						cont()
					.fail (err) ->
						cont(err)

				else
					cont()


			, (err) ->
				if err
					return d.reject(err)

				d.resolve(locals)


			return d.promise

			


		layout = (locals) ->

			locals.content ?= locals.body

			# console.log locals

			srcPath = p.resolve('.', p.join( opt.src,'layouts', locals.layout) )

			return get( srcPath )
			.then (meta) ->
				linkAndLoad(meta, srcPath)

			.then (meta) ->

				# console.log 'layout:', meta
				debugger

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

		locals = {}
		i = 0

		get( srcPath ) # get doc meta

		.then (meta) ->

			linkAndLoad(meta, srcPath)

		.then (meta) ->

			# console.log meta

			locals.uber(meta)
			locals.url = url.parse(req.url).pathname

			# use md in body
			if locals.body?
				# console.log locals.body
				locals.body = md( locals.body )

			if locals.template?
				return render(locals)
			else
				return locals


		.then loopLayout = (locals) ->


			i++

			# console.log 'loop:', i, opt.maxDepth

			if i > opt.maxDepth
				throw new Error('Max layout depth exceeded')

			# console.log 'loop'
			Q.when(locals).then (locals) ->

				# console.log 'loop layout:',locals
				# debugger

				if locals.layout?

					return loopLayout( layout(locals) )

				else
					return locals

		

		.then (locals) ->

			# console.log 'after render', locals

			locals.uber( opt.locals )

			# console.log 'final:',locals

			if locals.content?
				res.send( locals.content )

			else
				res.send( locals )



		.fail (err) ->

			# console.error err			

			if err.code is 'ENOENT' or err.code is 'ENOTDIR'
				next()
			else
				next(err)

		.done()




