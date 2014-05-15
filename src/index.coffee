###

DOCMOD

###

fs = require 'fs'
strm = require 'stream'
p = require 'path'
u = require 'url'
util = require 'util'
yaml = require 'js-yaml'
request = require 'request'
each = require 'each-async'
Q = require 'q'
jade = require 'jade'
md = require 'marked'
require 'obj-uber'

# defaults
opt = 
	host: 'localhost'
	src: './src'
	out: './out'
	maxDepth: 4
	filter: (doc, req) ->
		if doc.published?
			return doc.published
		else
			return true

module.exports = exports = (arg) ->

	opt = arg.uber opt

	return (req, res, next) ->

		compile( req )
		.then (doc) ->
			if !doc?
				next()
			else
				res.send(doc)
		.fail (err) ->
			next(err)

		


exports.compile = compile = (req, overridepath ) ->

		url = u.parse(req.url)

		path = overridepath ? url.pathname

		srcPath = p.resolve('.', p.join( opt.src,'docs',path))

		locals = 
			site: opt.site
			url: url.pathname

		i = 0 # layout loop count

		getDoc( srcPath ) # get doc meta

		.then (meta) ->

			linkAndLoad( req, meta, srcPath)

		.then (meta) ->

			locals.uber(meta)

			if locals.body?
				locals.body = md( locals.body )

			if locals.template?
				return render(locals)
			else
				return locals

		.then loopLayout = (locals) ->

			i++

			if i > opt.maxDepth
				throw new Error('Max layout depth exceeded')

			Q.when(locals).then (locals) ->

				if locals.layout?

					return loopLayout( layout(req, locals) )

				else
					return locals

		.then (locals) ->

			if !opt.filter(locals,req)
				return null

			if locals.content?
				return locals.content

			else
				return locals

		.fail (err) ->

			if err.code is 'ENOENT' or err.code is 'ENOTDIR'
				# console.error err.stack
				return null
			else
				throw err




getDoc = (path) ->

	d = Q.defer()

	if !path?
		d.resolve(null)

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
						doc.isindex = true
						d.resolve(doc)
			else
				d.reject(err)
		else
			doc = yaml.safeLoad(data)
			d.resolve(doc)

	return d.promise


linkAndLoad = (req, locals, path, isindex) ->

	if typeof locals isnt 'object'
		throw new Error('Locals ('+locals+') is not an object')

	isindex ?= locals.isindex

	d = Q.defer()

	each Object.keys(locals), (key, i, done) ->

		prop = locals[key]

		# debugger
		if prop is null
			return done()

		if prop.hasOwnProperty('$link')
			locals[key] = link( req, prop.$link, path, isindex )

			done()

		else if prop.hasOwnProperty('$load')

			newProp = ''

			rs = load( req, prop.$load, path, isindex )
			.on 'data', (data) ->
				newProp += data

			.on 'end', ->

				if rs.response?.headers['content-type']?.match(/application\/json/)
					locals[key] = JSON.parse(newProp)
				else
					locals[key] = newProp.toString()

				done()

			.on 'error', (err) ->
				console.error "DocMod: Error loading '%s' at '%s'", key, req.url
				console.error err.stack
				done(err)

		else if typeof prop is 'object'

			# debugger

			linkAndLoad( req, prop, path, isindex )
			.then -> done()
			.fail done

		else
			done()


	, (err) ->
		if err
			return d.reject(err)

		d.resolve(locals)


	return d.promise



link = (req, arg, callpath, isindex) ->
	reqopt = {}
	if typeof arg == 'string'
		reqopt.url = arg
	else
		reqopt = arg

	requrl = u.parse(req.url)
	opturl = u.parse(reqopt.url)
	reqpath = reqopt.url

	if !opturl.hostname? and opturl.pathname[0] isnt '/'

		if callpath?

			callpath = '/'+p.relative(opt.src, callpath )

			if !isindex
				callpath = p.resolve(callpath,'..')
				
		# pathname = requrl.pathname

		# if !isindex
		# 	pathname = p.resolve(requrl.pathname,'..')

		regex = /\\/g
		reqpath = p.join( callpath, reqopt.url ).replace(regex,'/')

	# console.log arg
	# console.log 'link path at %s: %s', req.url, reqpath

	return reqpath


load = (req, arg, callpath, isindex ) ->
	reqopt = {}
	if typeof arg == 'string'
		reqopt.url = arg
	else
		reqopt = arg
		reqopt.qs ?= reqopt.query # conform 'query' to 'qs' for request api

	requrl = u.parse(req.url)
	opturl = u.parse(reqopt.url)

	pathname = opturl.pathname

	if !opturl.hostname?

		if opturl.pathname[0] isnt '/'

			if callpath?

				if !isindex
					callpath = p.resolve(callpath,'..')

				pathname = p.join( callpath, reqopt.url )

				return fs.createReadStream( pathname, {encoding:'utf8'})
			else
				pathname = p.join( opturl.pathname, reqopt.url )

		reqopt.url = u.format
			protocol: 'http:'
			hostname: opt.host
			port: req.socket.localPort
			pathname: pathname
			search: requrl.query

	reqopt.headers = req.headers
	delete reqopt.headers['accept-encoding'] # this is to kill compression, TODO handle that specifically
	# kill these headers that screw up dynamic content in some environments
	delete reqopt.headers['content-length']
	delete reqopt.headers['if-none-match'] 

	# console.log reqopt

	return req.pipe( request( reqopt ) )


layout = (req, locals) ->

	locals.content ?= locals.body

	# console.log locals

	srcPath = p.resolve('.', p.join( opt.src,'layouts', locals.layout) )

	return getDoc( srcPath )
	.then (meta) ->
		linkAndLoad( req, meta, srcPath)

	.then (meta) ->

		# console.log 'layout:', meta
		# debugger

		delete locals.layout

		locals.uber(meta)

		if locals.template?
			return render(locals)
		else
			return locals


render = (locals) ->
	locals.basedir = p.resolve('.', p.join( opt.src,'layouts') )
	return Q.nfcall( jade.render, locals.template, locals )
	.then (rendered) ->
		locals.content = rendered
		delete locals.template
		return locals
