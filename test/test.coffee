
fs = require 'fs'
http = require 'http'
client = require 'superagent'
should = require 'should'
cheerio = require 'cheerio'
st = require 'st'

Doc = require '../doc'

express = require 'express'

docmod = require '../index'
config = require './config'

app = express()

app.set 'views', 'test/src/layouts'
app.set 'view engine', 'jade'
app.set 'view options',
	layout: false #use jade's block/extend instead

app.use docmod 
	src: './test/src'
	out: './test/out'
	locals:
		title: 'Test'
app.use(st({path:'./test/out', url:'/'}))

server = http.createServer(app).listen(3067);


describe 'server with docmod middleware', ->

	it 'responds', (done) ->

		client.get 'localhost:3067', (res) ->
			should.exist(res)
			done()

	it 'serves static doc with embeded body', (done) ->

		client.get 'localhost:3067/test-01', (res) ->
			should.exist(res)
			if res.error then return done(res.error)

			$ = cheerio.load(res.text)
			$('#title').text().should.eql( 'Static Embeded Test' )
			$('#body').text().should.eql('This is an embeded body.')

			done()

	it 'serves static doc with loaded body'#, (done) ->

		# client.get 'localhost:3067/test-02', (res) ->
		# 	should.exist(res)
		# 	if res.error then return done(res.error)

		# 	$ = cheerio.load(res.text)

	it 'returns our rendered test doc', (done) ->

		client.get 'localhost:3067/test-03', (res) ->
			should.exist(res)
			if res.error then return done(res.error)

			# console.log res

			$ = cheerio.load(res.text)
			$('#title').text().should.eql( 'Test Doc 3' )

			done()

after ->
	server.close()



