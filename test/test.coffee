
fs = require 'fs'
http = require 'http'
util = require 'util'

client = require 'superagent'
should = require 'should'
cheerio = require 'cheerio'
st = require 'st'

express = require 'express'

docmod = require '../index'
config = require './config'


app = express()

app.use docmod 
	src: './test/src'
	out: './test/out'
	locals:
		title: 'Site Test Title'
		siteData: 'some site data...'
app.use(st({path:'./test/out', url:'/'}))
# app.use(express.errorHandler())

server = http.createServer(app).listen(3067);


describe 'server with docmod middleware', ->

	it 'responds', (done) ->

		client.get 'localhost:3067', (res) ->
			should.exist(res)
			done()

	it 'responds with 404 if doc not found', (done) ->

		client.get 'localhost:3067/thisdoesnotexist', (res) ->
			res.status.should.eql(404)
			done()

describe 'static doc without template (test-01.1)', ->

	it 'returns json object where doc locals overwrite site locals', (done) ->
		client.get 'localhost:3067/test-01.1', (res) ->
			if res.error
				return done(res.error)
			
			res.header['content-type'].should.match(/application\/json/)
			res.body.title.should.eql('Simple Static Test')
			res.body.siteData.should.eql('some site data...')

			done()

describe 'static doc with embeded body and template (test-01.2)', ->

	it 'returns rendered html', (done) ->

		client.get 'localhost:3067/test-01.2', (res) ->
			if res.error
				return done(res.error)

			$ = cheerio.load(res.text)
			$('#title').text().should.eql('Static Embeded Template Test')
			$('#body').html().trim().should.eql('<p>This is an <em>embeded</em> body.</p>')

			done()

describe 'static doc with static layout but no templates (test-01.4)', ->

	it 'returns json object where doc locals overwrites layout locals', (done) ->
		client.get 'localhost:3067/test-01.4', (res) ->
			if res.error
				return done(res.error)
			
			res.header['content-type'].should.match(/application\/json/)
			res.body.title.should.eql('Simple Static Layout Test')
			res.body.layoutData.should.eql('Doc locals inherit this.')
			res.body.data.should.eql('some local doc data...')
			res.body.siteData.should.eql('some site data...')

			done()

describe 'static doc with loaded body and template (test-02)', ->

	it 'returns rendered html', (done) ->

		client.get 'localhost:3067/test-02', (res) ->
			if res.error
				return done(res.error)

			$ = cheerio.load(res.text)

			$('#title').text().should.eql('Static Loaded Template Test')

			done()


describe 'static doc loaded body, template and layout (test-02.1)', ->

	it 'returns rendered html with layout template and data', (done) ->

		client.get 'localhost:3067/test-02.1', (res) ->
			if res.error
				return done(res.error)

			$ = cheerio.load(res.text)

			$('#title').text().should.eql('Static Test Loaded With Layout')
			$('head title').text().should.eql('Layout Title | Static Test Loaded With Layout')
			$('#partial').text().should.eql('This is a fake partial.')

			done()


describe 'static doc with loaded body, template and multiple chained layouts (test-03, test-03.1)', ->

	it 'returns rendered html with nested layout templates', (done) ->

		client.get 'localhost:3067/test-03', (res) ->
			if res.error
				return done(res.error)

			$ = cheerio.load(res.text)

			$('#title').text().should.eql('Static Test Loaded With Nested Layouts')
			$('head title').text().should.eql('Nested Layout | Static Test Loaded With Nested Layouts')
			$('#partial').text().should.eql('This is a fake partial.')
			$('.wrapper').hasClass('nested').should.be.ok

			done()

	it 'subsequent calls do not interfere', (done) ->

		client.get 'localhost:3067/test-03', (res) ->
			if res.error
				return done(res.error)

			$ = cheerio.load(res.text)

			$('#title').text().should.eql('Static Test Loaded With Nested Layouts')
			$('head title').text().should.eql('Nested Layout | Static Test Loaded With Nested Layouts')
			$('#partial').text().should.eql('This is a fake partial.')
			$('.wrapper').hasClass('nested').should.be.ok

			done()

	it 'does not exceed max depth', (done) ->

		client.get 'localhost:3067/test-03.1', (res) ->
			# console.log res.status
			res.error.should.be.ok
			done()


describe 'simple async doc', ->

	it 'fetches from fsdb and returns json as normal', (done) ->

		client.get 'localhost:3067/test-04.0', (res) ->
			if res.error
				return done(res.error)

			# console.log res.body
			
			res.header['content-type'].should.match(/application\/json/)
			res.body.title.should.eql('Simple Test Async Doc')
			res.body.asyncData.should.eql('some cool data...')
			res.body.siteData.should.eql('some site data...')

			done()

	it 'fetches from fsdb and returns json probably a little faster this time', (done) ->

		client.get 'localhost:3067/test-04.0', (res) ->
			if res.error
				return done(res.error)
			
			res.header['content-type'].should.match(/application\/json/)
			res.body.title.should.eql('Simple Test Async Doc')
			res.body.asyncData.should.eql('some cool data...')
			res.body.siteData.should.eql('some site data...')

			done()

	it 'does not break with terminiating circular require', (done) ->

		client.get 'localhost:3067/test-04.2', (res) ->
			if res.error
				return done(res.error)

			# console.log res.body

			res.header['content-type'].should.match(/application\/json/)
			res.body.circularAsyncData.should.eql('some data')

			done()

	it 'does not break with indirect circular require', (done) ->

		client.get 'localhost:3067/test-04.1', (res) ->
			if res.error
				return done(res.error)

			# console.log JSON.stringify( res.body, null, '  ' )

			res.header['content-type'].should.match(/application\/json/)
			res.body.circularAsyncData.should.have.length(1)
			res.body.circularAsyncData.every( (doc) -> doc.tags.some((tag)-> tag == 'omg') ).should.be.ok

			done()

	it 'does not break with direct circular require', (done) ->

		client.get 'localhost:3067/test-04.4', (res) ->
			if res.error
				return done(res.error)

			res.body.title.should.eql('Direct Circular Reference!')
			res.body.asyncData.title.should.eql('Direct Circular Reference!')

			# console.log res.body

			done()



describe 'simple dynamic doc', ->

	it 'returns json data per request', (done) ->

		client.get 'localhost:3067/test-05?q=46', (res) ->
			if res.error
				return done(res.error)

			res.header['content-type'].should.match(/application\/json/)
			res.body.title.should.eql('Simple Test Dynamic Doc')
			res.body.q.should.eql(46)

			done()

	it 'multiple calls do not interfere', (done) ->

		client.get 'localhost:3067/test-05?q=01'

		client.get 'localhost:3067/test-05?q=23', (res) ->
			if res.error
				return done(res.error)

			res.header['content-type'].should.match(/application\/json/)
			res.body.title.should.eql('Simple Test Dynamic Doc')
			res.body.q.should.eql(23)

			done()

		client.get 'localhost:3067/test-05?q=02'


describe 'simple async dynamic doc', ->

	it 'fetches from fsdb per request and returns json', (done) ->

		client.get 'localhost:3067/test-06?tag=foo', (res) ->
			if res.error
				return done(res.error)

			# console.log res.body.dynamicAsyncData

			res.header['content-type'].should.match(/application\/json/)
			res.body.dynamicAsyncData.should.have.length(4)
			res.body.dynamicAsyncData.every( (doc) -> doc.tags.some((tag)-> tag == 'foo') ).should.be.ok

			done()


describe 'doc with loaded template and body and nested async dymanic layouts', ->

	it 'pulls itself together', (done) ->

		client.get 'localhost:3067/test-07', (res) ->
			if res.error
				return done(res.error)

			# console.log res.text

			$ = cheerio.load(res.text)

			$('#title').text().should.eql('Integrated Test')
			$('head title').text().should.eql('Nested Dynamic Async Layout | Integrated Test')
			$('ul.items').children().should.have.length(10)

			done()


# describe 'doc with linked resource', ->

# describe 'recursive load and link objects and arrays', ->













after ->
	server.close()



