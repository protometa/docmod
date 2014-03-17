
fsdb = require 'fsdb'
Q = require 'q'
modmatch = require 'mod-match'

module.exports =
	title: 'Simple Test Async Doc'
	tags:['baz','qux']

	asyncData: Q.ninvoke( fsdb, 'findOne', './test/src/docs/*', modmatch( -> @title == 'Simple Static Test' ) )
		.then (doc) -> doc.data
