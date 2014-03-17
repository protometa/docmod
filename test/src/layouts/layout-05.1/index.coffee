
fsdb = require 'fsdb'
Q = require 'q'
modmatch = require 'mod-match'

module.exports = 

	layoutTitle: "Nested Dynamic Async Layout",
	wrapperClass: "nested",
	load:
		template: "template.jade"

	layout:"layout-03"

	items: Q.ninvoke( fsdb, 'findAll', './test/src/docs/*', modmatch( -> @tags.some( (tag) -> tag == 'baz' )))
