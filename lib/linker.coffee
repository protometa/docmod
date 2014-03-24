
p = require 'path'
u = require 'url'

yaml = require 'js-yaml'


Linker = (path) ->
	@path = path
	return this

Linker.prototype.resolve = (req) ->
	url = u.parse(req.url)
	pathp = u.parse(@path)
	reqpath = @path

	if !pathp.hostname?

		if pathp.pathname[0] is '/'
			pathname = @path
		else
			pathname = p.join( url.pathname, @path )

		reqpath = pathname

	return reqpath




Linker.yamlType = new yaml.Type '!link',
		loadKind: 'scalar'
		loadResolver: (state) ->
			state.result = new Linker( state.result )
			return true
		dumpInstanceOf: Linker
		dumpRepresenter: (linker) -> linker.path


module.exports = Linker










