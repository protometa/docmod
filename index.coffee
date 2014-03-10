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
	run static on src after docmod /!\

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
merge = require 'utils-merge'

module.exports = (opt) ->

	src = opt.src ? './src'
	out = opt.out ? './out'

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
					

			# meta may be function that accepts req (dynamic)
			if typeof meta == 'function'
				meta = meta(req)

			# meta may return promise (asynchronous)
			Q.when( meta ).then (meta) ->

				# load files...

				fs.readdir path, (err,files) ->
					if err and err.code != 'ENOTDIR' then return d.reject(err)

					if files?
						async.each files, (file,cb) ->

							fileSplit = file.split('.')

							key = fileSplit[0]

							if key == 'index'
								return cb()


							fs.readFile p.join(path, file), {encoding:'utf8'}, (err, data) ->
								if err then return cb(err)

								if fileSplit[fileSplit.length-1] == 'md'
									data = md( data )

								meta[key] = data
								cb()

						, (err) ->
							if err then return d.reject(err)

							d.resolve(meta)


					else

						d.resolve(meta)

			.done()

			return d.promise



		srcPath = p.resolve('.',p.join(src,'docs',url.parse(req.url).path))

		# console.log srcPath			

		docMeta = null
		layoutMeta = null
		locals = {}

		merge locals, opt.site
		

		get( srcPath ) # get doc meta
		.then (meta) ->

			merge locals, meta
			locals.url = url.parse(req.url).path

			srcPath = p.resolve('.', p.join(src,'views', meta.view) )

			get( srcPath ) # get layout meta

		.then (meta) ->

			merge locals, meta

			# console.log locals

			jade.render meta.template, locals, (err, rendered) ->
				if err then return next(err)

				# console.log rendered

				# res.setHeader('content-type', 'text/html') # default header for clean static urls
				# fs.writeFile p.resolve('.', p.join(out, locals.url) ), rendered, next

				res.send( rendered )

		.fail (err) ->

			if err.code == 'MODULE_NOT_FOUND'
				next()
			else
				next(err)

		.done()




