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
			locals[key] = link( req, prop.$link, isindex )

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

			.on 'error', done

		else if typeof prop is 'object'

			# debugger

			linkAndLoad( req, prop, path, isindex )
			.then ->
				done()
			.fail (err) ->
				done(err)

		else
			done()


	, (err) ->
		if err
			return d.reject(err)

		d.resolve(locals)


	return d.promise



link = (req, arg, isindex) ->
	reqopt = {}
	if typeof arg == 'string'
		reqopt.url = arg
	else
		reqopt = arg

	requrl = u.parse(req.url)
	opturl = u.parse(reqopt.url)
	reqpath = reqopt.url

	if !opturl.hostname?

		if opturl.pathname[0] is '/'
			reqpath = reqopt.url
		else
			pathname = requrl.pathname

			if !isindex
				pathname = requrl.pathname
				pathname = pathname.split('/')
				pathname = pathname.slice(0,pathname.length-1).join('/')

			reqpath = p.join( pathname, reqopt.url )

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

				if isindex
					pathname = p.join( callpath, reqopt.url )
				else
					callpath = callpath.split('/')
					callpath = callpath.slice(0,callpath.length-1).join('/')

					pathname = p.join( callpath, reqopt.url )

				return fs.createReadStream( pathname, {encoding:'utf8'})
			else
				pathname = p.join( opturl.pathname, reqopt.url )

		reqopt.url = u.format
			protocol: 'http:'
			hostname: 'localhost'
			port: req.socket.localPort
			pathname: pathname
			search: requrl.query

	reqopt.headers ?= { 'accept-encoding': null }

	# console.log opt

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


# breadcrumbs = (locals) ->

# 	d = Q.defer()

# 	urlsplit = locals.url.split('/').slice(1)
# 	breadcrumbs = [
# 		url: '/'
# 		title: 'Home'
# 	]

# 	each urlsplit, (part,i,done) ->

# 		console.log i,part

# 		crumb = 
# 			url: '/'+urlsplit.slice(0,i+1).join('/')

# 		console.log crumb

# 		srcPath = p.resolve('.', p.join( opt.src,'docs', crumb.url ))

# 		getDoc( srcPath )
# 		.then (meta) ->
# 			console.log 'meta', meta
# 			crumb.title = meta.title
# 			breadcrumbs[i+1] = crumb
# 			done()
# 		.fail (err) ->
# 			console.log err
# 			if err.code is 'ENOENT' or err.code is 'ENOTDIR'
# 				crumb.dir = part
# 				breadcrumbs[i+1] = crumb
# 				done()
# 			else
# 				done(err)
# 	, (err) ->
# 		if err then return d.reject(err)

# 		console.log breadcrumbs

# 		locals.breadcrumbs = breadcrumbs

# 		d.resolve(locals)

# 	d.promise
