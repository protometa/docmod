
http = require 'http'
superagent = require 'superagent'
should = require 'should'

connect = require 'connect'
server = null


docpad = require 'docpad-redux'
config = require './config'

app = connect()

app.use(docpad(config))

server = http.createServer(app).listen(3067);


describe 'test server', ->

	it 'responds', (done) ->

		superagent.get 'localhost:3067', (res) ->
			should.exist(res)

			done()


after ->
	server.close()













