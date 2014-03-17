
fsdb = require 'fsdb'
Q = require 'q'
modmatch = require 'mod-match'
uber = require 'uber'


module.exports =
	title: 'Simple Test Terminating Circular Async Doc'
	data: 'some data'
	tags: ['baz','qux']
	circularAsyncData: Q.ninvoke( fsdb, 'findOne', './test/src/docs/*', modmatch( -> @title == 'Simple Test Terminating Circular Async Doc' ) )
		.then (doc) -> doc.data
