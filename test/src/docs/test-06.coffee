
fsdb = require 'fsdb'
Q = require 'q'
modmatch = require 'mod-match'

module.exports =
	title: 'Simple Test Dynamic Async Doc'
	dynamicAsyncData: (req) -> 
		Q.ninvoke( fsdb, 'findAll', './test/src/docs/*', modmatch( -> @tags.some( (tag) -> tag == req.query.tag ) ) )



