
fsdb = require 'fsdb'
Q = require 'q'
modmatch = require 'mod-match'

module.exports =
	title: 'Direct Circular Reference!'

	asyncData: Q.ninvoke( fsdb, 'findOne', './test/src/docs/*', modmatch( -> @title == 'Direct Circular Reference!' ) )