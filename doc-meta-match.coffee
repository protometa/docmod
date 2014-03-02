
Doc = require './doc.coffe'

# YAML = require 'yamljs'
# #Doc = require 'doc'
# metaRegex = /^\s*(([^\s\d\w])\2{2,})(?:\x20*([a-z]+))?([\s\S]*?)\1/

module.exports = (testfunc) ->

	return ([path,data]...,cb) ->

		doc = new Doc(path, data)

		doc.getMeta().then (meta) ->

			if testfunc.call(meta)

				cb( null, doc )

			else

				cb()

		.done (err) ->

			cb( err )



