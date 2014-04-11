
fs = require 'fs'
http = require 'http'
util = require 'util'

client = require 'superagent'
should = require 'should'
cheerio = require 'cheerio'
st = require 'st'

express = require 'express'

docmod = require '../lib/index'
# config = require './config'

fscan = require 'fscan'
match = require 'mod-query-match'

app = server = null

app = express()

app.use docmod 
	src: './test/src'
	out: './test/out'
	site:
		title: 'Site Test Title'
		siteData: 'some site data...'


# app.get '/loadertest1', (req,res) ->
# 	new Loader('resource').resolve(req).pipe(res)

# app.get '/loadertest2', (req,res) ->
# 	new Loader('/loadertest1/resource').resolve(req).pipe(res)

# app.get '/loadertest3', (req,res) ->
# 	new Loader('http://localhost:3067/loadertest1/resource').resolve(req).pipe(res)	

# app.get '/loadertest1/resource', (req,res) ->
# 	res.send success:true

app.use app.router

app.use(st({path:'./test/src/docs', url:'/',passthrough:true}))
app.use(st({path:'./test/src/layouts', url:'/',passthrough:true}))
# app.use(express.errorHandler())

app.use (req,res,next) ->
	res.status(404)
	docmod.compile(req,'/404')
	.then ( text ) ->
		res.send( text )
	.fail (err) ->
		next(err)


app.get '/fsdb/findone', (req,res,next) ->
	fscan.findOne './test/src/docs/**/*.yaml', match(req.query), (err,doc) ->
		if err
			console.log err
			res.status(500)
			res.end()
		res.send(doc)

app.get '/fsdb/findall', (req,res,next) ->
	fscan.findAll './test/src/docs/**/*.yaml', match(req.query), (err,docs) ->
		if err
			console.log err
			res.status(500)
			res.end()
		res.send(docs)



server = http.createServer(app).listen(3067);


	# debugger

	# begin tests


# describe 'Loader', ->

# 	it 'proxies request with relative path', (done) ->

# 		client.get 'localhost:3067/loadertest1', (res) ->
# 			res.body.success.should.be.true
# 			done()

# 	it 'proxies request with absolute path', (done) ->

# 		client.get 'localhost:3067/loadertest2', (res) ->
# 			res.body.success.should.be.true
# 			done()

# 	it 'proxies request with full path', (done) ->

# 		client.get 'localhost:3067/loadertest3', (res) ->
# 			res.body.success.should.be.true
# 			done()



describe 'server with docmod middleware', ->

	it 'responds', (done) ->

		client.get 'localhost:3067', (res) ->
			should.exist(res)
			done()

	it 'responds with 404 if doc not found', (done) ->

		client.get 'localhost:3067/thisdoesnotexist', (res) ->
			res.status.should.eql(404)
			done()


describe 'doc', ->

	it 'returns json object where doc locals overwrite site locals', (done) ->

		client.get 'localhost:3067/test-2.0.0', (res) ->
			if res.error
				return done(res.error)

			# console.log res.body
			
			res.header['content-type'].should.match(/application\/json/)
			res.body.title.should.eql('Simple Static Doc')
			res.body.site.siteData.should.eql('some site data...')

			done()


describe 'doc with $load and $link tags', ->

	it 'allows static resources', (done) ->

		client.get 'http://localhost:3067/test-2.1.0/body.md', (res) ->
			if res.error
				return done(res.error)
			# console.log res.text
			res.text.should.eql('This is an *external* body.')
			done()

	it 'resolves and replaces props', (done) ->

		client.get 'localhost:3067/test-2.1.0', (res) ->
			if res.error
				return done(res.error)
			# console.log res.body

			res.body.title.should.eql('Link and Load')
			res.body.text.should.eql('This is an *external* body.')
			res.body.image.should.eql('/test-2.1.0/picture.jpg')

			done()

	it 'works on deep properties', (done) ->

		client.get 'localhost:3067/test-2.1.1', (res) ->
			if res.error
				return done(res.error)

			# console.log res.body

			res.body.title.should.eql('Deep Link Load Test')
			res.body.obj.text.should.eql('This is an *external* body.')
			res.body.arr[1].should.eql('/test-2.1.1/picture.jpg')

			done()

	it 'loads and links sibling resources in named metadata files', (done) ->

		client.get 'localhost:3067/test-2.1.1/named', (res) ->
			if res.error
				return done(res.error)

			res.body.title.should.eql('Deep Link Load Test')
			res.body.obj.text.should.eql('This is an *external* body.')
			res.body.arr[1].should.eql('/test-2.1.1/picture.jpg')

			done()



describe 'doc with body and template', ->

	it 'returns rendered html', (done) ->

		client.get 'localhost:3067/test-2.2.0', (res) ->
			if res.error
				return done(res.error)

			$ = cheerio.load(res.text)
			$('#title').text().should.eql('Render Test')
			$('#body').html().trim().should.eql('<p>This is an <em>external</em> body.</p>')

			done()

describe 'doc with layout but no body or templates', ->

	it 'returns json object where doc locals overwrites layout locals', (done) ->
		client.get 'localhost:3067/test-2.3.0', (res) ->
			if res.error
				return done(res.error)

			res.header['content-type'].should.match(/application\/json/)
			res.body.title.should.eql('Basic Layout Test')
			res.body.layoutTitle.should.eql('Layout Title')
			res.body.site.siteData.should.eql('some site data...')

			done()


describe 'doc with loaded body, template and layout', ->

	it 'returns rendered html with layout template and data', (done) ->

		# this fails because layout templates are loaded incorrectly based on orginal req url and are loading doc templates
		# relative load links should probably be read from filesystem directly

		client.get 'localhost:3067/test-2.4.0', (res) ->
			if res.error
				return done(res.error)

			# console.log res.text

			$ = cheerio.load(res.text)
			$('#title').text().should.eql('Layout Template Test')
			$('head title').text().should.eql('Layout With Template | Layout Template Test')
			$('#partial').text().should.eql('This is a fake partial.')


			done()			

describe 'doc with loaded body, template and nested layouts', ->

	it 'returns rendered html with nested layout templates', (done) ->

		client.get 'localhost:3067/test-2.5.0', (res) ->
			if res.error
				return done(res.error)

			$ = cheerio.load(res.text)
			$('#title').text().should.eql('Nested Layout Template Test')
			$('head title').text().should.eql('Nested Layout | Nested Layout Template Test')
			$('#partial').text().should.eql('This is a fake partial.')
			$('.wrapper').hasClass('nested').should.be.ok

			done()

	it 'subsequent calls do not interfere', (done) ->

		client.get 'localhost:3067/test-2.5.0', (res) ->
			if res.error
				return done(res.error)

			$ = cheerio.load(res.text)
			$('#title').text().should.eql('Nested Layout Template Test')
			$('head title').text().should.eql('Nested Layout | Nested Layout Template Test')
			$('#partial').text().should.eql('This is a fake partial.')
			$('.wrapper').hasClass('nested').should.be.ok

			done()

	it 'does not exceed max depth', (done) ->

		client.get 'localhost:3067/test-2.5.1', (res) ->
			# console.log res.status
			res.error.should.be.ok
			done()	


describe 'simple async doc', ->

	it 'fetches from fscan and returns json', (done) ->

		client.get 'localhost:3067/test-2.6.0', (res) ->
			if res.error
				return done(res.error)

			res.header['content-type'].should.match(/application\/json/)
			res.body.title.should.eql('Simple Test Async Doc')
			res.body.async.title.should.eql('Simple Static Doc')

			done()

	it 'fetches from fscan and returns json maybe a little faster this time', (done) ->

		client.get 'localhost:3067/test-2.6.0', (res) ->
			if res.error
				return done(res.error)
			
			res.header['content-type'].should.match(/application\/json/)
			res.body.title.should.eql('Simple Test Async Doc')
			res.body.async.title.should.eql('Simple Static Doc')

			done()

describe 'simple async dynamic doc', ->

	it 'fetches from fscan per request and returns json', (done) ->

		client.get 'localhost:3067/test-2.6.1?tags[]=test', (res) ->
			if res.error
				return done(res.error)

			res.header['content-type'].should.match(/application\/json/)
			res.body.dynamicAsync.should.have.length(3)
			res.body.dynamicAsync.every( (doc) -> doc.tags.some((tag)-> tag == 'test') ).should.be.true

			done()

describe 'integrated doc with loaded template and body and nested async dymanic layouts', ->

	it 'pulls itself together', (done) ->

		client.get 'localhost:3067/test-2.7.0', (res) ->
			if res.error
				return done(res.error)

			$ = cheerio.load(res.text)
			$('#title').text().should.eql('Integrated Test')
			$('head title').text().should.eql('Nested Async Layout | Integrated Test')
			$('ul.items').children().should.have.length(3)
			$('#partial').text().should.eql('This is a real partial.')

			done()


describe 'filter method', ->

	it 'filters out docs that dont match', (done) ->

		client.get 'localhost:3067/test-2.8.0', (res) ->
			res.status.should.eql(404)
			done()

	it 'allows docs that do match', (done) ->
		client.get 'localhost:3067/test-2.8.1', (res) ->
			res.status.should.eql(200)
			done()


describe 'standalone compiler', ->

	it 'overides the req url and serves the doc at the specified path', (done) ->

		client.get 'localhost:3067/thisdoesnotexist', (res) ->
			res.status.should.eql(404)
			$ = cheerio.load(res.text)
			$('#content').text().trim().should.eql('404: Page not found!')
			done()



# after ->
# 	server.close()



