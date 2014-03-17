
fsdb = require 'fsdb'
Q = require 'q'
modmatch = require 'mod-match'
uber = require 'uber'


module.exports =
	title: 'Simple Test Circular Async Doc 2'
	data: 'some data'
	tags: ['omg','qux']
	circularAsyncData: Q.ninvoke( fsdb, 'findAll', './test/src/docs/*', modmatch( -> match = @tags.some( (tag) -> tag == 'omg' )))
