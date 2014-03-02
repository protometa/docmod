
YAML = require 'yamljs'
metaRegex = /^\s*(([^\s\d\w])\2{2,})(?:\x20*([a-z]+))?([\s\S]*?)\1/
fs = require 'fs'
Q = require 'q'

class Doc

	constructor: (path,data) ->
		if !path? then throw new TypeError('no docment path provided')

		@path = path
		@data = data


	getData: (cb) ->
		async = (cb) =>

			if @data
				cb(null, @data)
			else

				fs.readFile @path, (err,data) =>
					if err then return cb(err)

					@data = data

					cb(null, data)

		if cb?
			async(cb)
		else
			return Q.nfcall( async )			


	getPath: (cb) -> 
		async = (cb) => cb(null, @path)
		if cb? then async(cb) else return Q.nfcall( async )


	getMeta: (cb) ->
		async = (cb) =>

			if @meta
				cb(null, @meta)

			else

				@getData (err, data) =>
					if err then return cb(err)

					@match = @match || metaRegex.exec( data )

					if @match
						@meta = YAML.parse( @match[4].trim().replace(/\t/g,'    ') )

						# set default url in meta
						if !@meta.url?
							splitpath = @path.split('/')
							splitname = splitpath[splitpath.length-1].split('.')
							if splitname[0] == 'index'
								@meta.url = splitpath.slice(0,splitpath.length-2).join('/')
							else
								splitpath[splitpath.length-1] = splitname[0]
								@meta.url = splitpath.join('/')

						cb(null, @meta)

					else
						cb()

		if cb?
			async(cb)
		else
			return Q.nfcall( async )


		
	getBody: (cb) ->
		async = (cb) =>

			if @body
				cb(null, @body)

			else

				@getData (err,data) ->
					if err then return cb(err)

					@match = @match || metaRegex.exec( data )

					if @match
						@body = data.substring( @match[0].length).trim()

						cb(null, @body)

					else
						cb()

		if cb?
			async(cb)
		else
			return Q.nfcall( async )


	render: (cb) ->
		cb(null,'testing...')


module.exports = Doc


