
p = require 'path'
yaml = require 'js-yaml'
fs = require 'fs'


match = (doc,query) ->

	for key of query

		if typeof doc[key] == 'object' and typeof query[key] == 'object'
			if doc[key].length? and query[key].length?
				return query[key].every( (queryItem) -> doc[key].some( (docItem) -> docItem == queryItem ) )
			return match( doc[key], query[key] )
		else if doc[key] != query[key]
			return false
	
	return true

module.exports = (query) ->

	# console.log 'query',query

	return (file,cb) ->

		file = p.resolve '.', file

		# console.log file

		fs.readFile file, 'utf8', (err,data) ->
			if err
				return cb(null,false)

			try
				doc = yaml.safeLoad(data)
			catch err
				# console.log 'match err:', err
				return cb(null,false)

			if match(doc,query)
				return cb(null,doc)
			else
				return cb(null,false)
		