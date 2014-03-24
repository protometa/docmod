
p = require 'path'
u = require 'url'
fs = require 'fs'

request = require 'request'
yaml = require 'js-yaml'


Loader = (path) ->
	@path = path
	return this

Loader.prototype.resolve = (req, callpath) ->
	url = u.parse(req.url)
	pathp = u.parse(@path)
	reqpath = @path

	if !pathp.hostname?

		if pathp.pathname[0] is '/'
			pathname = @path
		else
			if callpath?
				pathname = p.join( callpath, @path )
				return fs.createReadStream( pathname, {encoding:'utf8'})
			else
				pathname = p.join( url.pathname, @path )

		reqpath = u.format
				protocol: 'http'
				hostname: 'localhost'
				port: req.socket.localPort
				pathname: pathname

	# console.log reqpath

	return req.pipe( request( {uri: reqpath, headers: { 'accept-encoding': null } } ) )




Loader.yamlType = new yaml.Type '!load',
		loadKind: 'scalar'
		loadResolver: (state) ->
			state.result = new Loader( state.result )
			return true
		dumpInstanceOf: Loader
		dumpRepresenter: (loader) -> loader.path


module.exports = Loader










