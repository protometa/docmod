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



link = (req, arg) ->
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


load = (req, arg, callpath) ->
	opt = {}
	if typeof arg == 'string'
		opt.url = arg
	else
		opt = arg
		opt.qs ?= opt.query # conform 'query' to 'qs' for request api

	requrl = u.parse(req.url)
	opturl = u.parse(opt.url)

	pathname = opturl.pathname

	if !opturl.hostname?

		if opturl.pathname[0] isnt '/'

			if callpath?
				pathname = p.join( callpath, opt.url )
				return fs.createReadStream( pathname, {encoding:'utf8'})
			else
				pathname = p.join( opturl.pathname, opt.url )

		opt.url = u.format
				protocol: 'http'
				hostname: 'localhost'
				port: req.socket.localPort
				pathname: pathname
				search: requrl.query

	opt.headers ?= { 'accept-encoding': null }

	

	return req.pipe( request( opt ) )


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

			
			fs.readFile trypath, 'utf8', (err,data) ->
				if err
					if err.code is 'ENOENT'

						trypath = p.join path, 'index.yaml'

						fs.readFile trypath, 'utf8', (err,data) ->
							if err
								d.reject(err)
							else
								doc = yaml.safeLoad(data)
								d.resolve(doc)
					else
						d.reject(err)
				else
					doc = yaml.safeLoad(data)
					d.resolve(doc)

			return d.promise


		linkAndLoad = (locals, path) ->

			d = Q.defer()

			async.each Object.keys(locals), (key, cont) ->

				prop = locals[key]

				# debugger

				if prop.hasOwnProperty('$link')
					locals[key] = link( req, prop.$link )

					cont()

				else if prop.hasOwnProperty('$load')

					newProp = ''

					rs = load( req, prop.$load, path )
					.on 'data', (data) ->
						newProp += data

					.on 'end', ->

						if rs.response?.headers['content-type']?.match(/application\/json/)
							locals[key] = JSON.parse(newProp)
						else
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

		srcPath = p.resolve('.', p.join( opt.src,'docs',url.parse(req.url).pathname))

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




