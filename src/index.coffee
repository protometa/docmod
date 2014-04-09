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



link = (req, arg, isindex) ->
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
			pathname = requrl.pathname

			if !isindex
				pathname = requrl.pathname
				pathname = pathname.split('/')
				pathname = pathname.slice(0,pathname.length-1).join('/')

			reqpath = p.join( pathname, opt.url )

	return reqpath


load = (req, arg, callpath, isindex ) ->
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

				if isindex
					pathname = p.join( callpath, opt.url )
				else
					callpath = callpath.split('/')
					callpath = callpath.slice(0,callpath.length-1).join('/')

					pathname = p.join( callpath, opt.url )

					console.log 'pathname:', pathname

				return fs.createReadStream( pathname, {encoding:'utf8'})
			else
				pathname = p.join( opturl.pathname, opt.url )

		opt.url = u.format
			protocol: 'http:'
			hostname: 'localhost'
			port: req.socket.localPort
			pathname: pathname
			search: requrl.query

	opt.headers ?= { 'accept-encoding': null }

	# console.log opt

	return req.pipe( request( opt ) )



module.exports = (opt) ->

	# inherit defaults
	opt.uber
		src: './src'
		out: './out'
		maxDepth: 4

	return (req, res, next) ->

		# console.log 'docmod headres',req.headers

		url = u.parse(req.url)

		get = (path) ->

			d = Q.defer()

			if !path
				console.log 'no path?', path
				d.resolve(null)

			# console.log path

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


		linkAndLoad = (locals, path, isindex) ->

			isindex ?= locals.isindex

			d = Q.defer()

			each Object.keys(locals), (key, i, done) ->

				prop = locals[key]

				# debugger

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

					linkAndLoad( prop, path, isindex )
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
			locals.basedir = p.resolve('.', p.join( opt.src,'layouts') )
			return Q.nfcall( jade.render, locals.template, locals )
			.then (rendered) ->
				locals.content = rendered
				delete locals.template
				return locals

		breadcrumbs = (locals) ->

			d = Q.defer()

			urlsplit = locals.url.split('/').slice(1)
			breadcrumbs = [
				url: '/'
				title: 'Home'
			]

			each urlsplit, (part,i,done) ->

				console.log i,part

				crumb = 
					url: '/'+urlsplit.slice(0,i+1).join('/')

				console.log crumb

				srcPath = p.resolve('.', p.join( opt.src,'docs', crumb.url ))

				get( srcPath )
				.then (meta) ->
					console.log 'meta', meta
					crumb.title = meta.title
					breadcrumbs[i+1] = crumb
					done()
				.fail (err) ->
					console.log err
					if err.code is 'ENOENT' or err.code is 'ENOTDIR'
						crumb.dir = part
						breadcrumbs[i+1] = crumb
						done()
					else
						done(err)
			, (err) ->
				if err then return d.reject(err)

				console.log breadcrumbs

				locals.breadcrumbs = breadcrumbs

				d.resolve(locals)

			d.promise


		# console.log url.parse(req.url)

		srcPath = p.resolve('.', p.join( opt.src,'docs',url.parse(req.url).pathname))

		# console.log srcPath

		locals = 
			site: opt.site

		i = 0

		get( srcPath ) # get doc meta

		.then (meta) ->

			# console.log meta

			linkAndLoad(meta, srcPath)

		.then (meta) ->

			# console.log meta

			locals.uber(meta)
			locals.url = url.parse(req.url).pathname

			# locals

		# .then (locals) ->

		# 	breadcrumbs(locals)
			
		# .then (locals) ->	

			# console.log locals

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

			# console.log locals


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




