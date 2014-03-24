
fs = require 'fs'
http = require 'http'
util = require 'util'

client = require 'superagent'
should = require 'should'
cheerio = require 'cheerio'
st = require 'st'

express = require 'express'

docmod = require '../lib/index'
Loader = require '../lib/loader'
config = require './config'

fsdb = require 'fsdb'
match = require './mod-query-match'

app = server = null

before = ->

	app = express()

	app.use docmod 
		src: './test/src'
		out: './test/out'
		locals:
			title: 'Site Test Title'
			siteData: 'some site data...'


	app.get '/loadertest1', (req,res) ->
		new Loader('resource').resolve(req).pipe(res)

	app.get '/loadertest2', (req,res) ->
		new Loader('/loadertest1/resource').resolve(req).pipe(res)

	app.get '/loadertest3', (req,res) ->
		new Loader('http://localhost:3067/loadertest1/resource').resolve(req).pipe(res)	

	app.get '/loadertest1/resource', (req,res) ->
		res.send success:true

	app.get '/fsdb', (req,res) ->

		fsdb.findAll './test/src/docs/*', match(req.query), (err,docs) ->
			if err then return next(err)

			res.send(docs)


	app.use(st({path:'./test/src/docs', url:'/'}))
	app.use(st({path:'./test/src/layouts', url:'/'}))
	# app.use(express.errorHandler())

	server = http.createServer(app).listen(3067);


	# debugger

	# begin tests


describe 'Loader', ->

	it 'proxies request with relative path', (done) ->

		client.get 'localhost:3067/loadertest1', (res) ->
			res.body.success.should.be.true
			done()

	it 'proxies request with absolute path', (done) ->

		client.get 'localhost:3067/loadertest2', (res) ->
			res.body.success.should.be.true
			done()

	it 'proxies request with full path', (done) ->

		client.get 'localhost:3067/loadertest3', (res) ->
			res.body.success.should.be.true
			done()



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
			res.body.siteData.should.eql('some site data...')

			done()


describe 'doc with !load and !link tags', ->

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

			res.body.title.should.eql('Winches')
			res.body.text.should.eql('This is an *external* body.')
			res.body.image.should.eql('/test-2.1.0/picture.jpg')

			done()

	it 'works one deep properties', (done) ->

		client.get 'localhost:3067/test-2.1.1', (res) ->
			if res.error
				return done(res.error)

			# console.log res.body

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

			# console.log res.body
			# console.log res.text
			
			res.header['content-type'].should.match(/application\/json/)
			res.body.title.should.eql('Basic Layout Test')
			res.body.layoutTitle.should.eql('Layout Title')
			res.body.siteData.should.eql('some site data...')

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

	it 'fetches from fsdb and returns json', (done) ->

		client.get 'localhost:3067/test-04.0', (res) ->
			if res.error
				return done(res.error)

			# console.log res.body
			
			res.header['content-type'].should.match(/application\/json/)
			res.body.title.should.eql('Simple Test Async Doc')
			res.body.asyncData.should.eql('some cool data...')
			res.body.siteData.should.eql('some site data...')

			done()

# describe 'static doc with loaded body and template (test-02)', ->

# 	it 'returns rendered html', (done) ->

# 		client.get 'localhost:3067/test-02', (res) ->
# 			if res.error
# 				return done(res.error)

# 			$ = cheerio.load(res.text)

# 			$('#title').text().should.eql('Static Loaded Template Test')

# 			done()


# describe 'static doc loaded body, template and layout (test-02.1)', ->

# 	it 'returns rendered html with layout template and data', (done) ->

# 		client.get 'localhost:3067/test-02.1', (res) ->
# 			if res.error
# 				return done(res.error)

# 			$ = cheerio.load(res.text)

# 			$('#title').text().should.eql('Static Test Loaded With Layout')
# 			$('head title').text().should.eql('Layout Title | Static Test Loaded With Layout')
# 			$('#partial').text().should.eql('This is a fake partial.')

# 			done()


# describe 'static doc with loaded body, template and multiple chained layouts (test-03, test-03.1)', ->

# 	it 'returns rendered html with nested layout templates', (done) ->

# 		client.get 'localhost:3067/test-03', (res) ->
# 			if res.error
# 				return done(res.error)

# 			$ = cheerio.load(res.text)

# 			$('#title').text().should.eql('Static Test Loaded With Nested Layouts')
# 			$('head title').text().should.eql('Nested Layout | Static Test Loaded With Nested Layouts')
# 			$('#partial').text().should.eql('This is a fake partial.')
# 			$('.wrapper').hasClass('nested').should.be.ok

# 			done()

# 	it 'subsequent calls do not interfere', (done) ->

# 		client.get 'localhost:3067/test-03', (res) ->
# 			if res.error
# 				return done(res.error)

# 			$ = cheerio.load(res.text)

# 			$('#title').text().should.eql('Static Test Loaded With Nested Layouts')
# 			$('head title').text().should.eql('Nested Layout | Static Test Loaded With Nested Layouts')
# 			$('#partial').text().should.eql('This is a fake partial.')
# 			$('.wrapper').hasClass('nested').should.be.ok

# 			done()

# 	it 'does not exceed max depth', (done) ->

# 		client.get 'localhost:3067/test-03.1', (res) ->
# 			# console.log res.status
# 			res.error.should.be.ok
# 			done()


# describe 'simple async doc', ->

# 	it 'fetches from fsdb and returns json as normal', (done) ->

# 		client.get 'localhost:3067/test-04.0', (res) ->
# 			if res.error
# 				return done(res.error)

# 			# console.log res.body
			
# 			res.header['content-type'].should.match(/application\/json/)
# 			res.body.title.should.eql('Simple Test Async Doc')
# 			res.body.asyncData.should.eql('some cool data...')
# 			res.body.siteData.should.eql('some site data...')

# 			done()

# 	it 'fetches from fsdb and returns json probably a little faster this time', (done) ->

# 		client.get 'localhost:3067/test-04.0', (res) ->
# 			if res.error
# 				return done(res.error)
			
# 			res.header['content-type'].should.match(/application\/json/)
# 			res.body.title.should.eql('Simple Test Async Doc')
# 			res.body.asyncData.should.eql('some cool data...')
# 			res.body.siteData.should.eql('some site data...')

# 			done()

# 	it 'does not break with terminiating circular require', (done) ->

# 		client.get 'localhost:3067/test-04.2', (res) ->
# 			if res.error
# 				return done(res.error)

# 			# console.log res.body

# 			res.header['content-type'].should.match(/application\/json/)
# 			res.body.circularAsyncData.should.eql('some data')

# 			done()

# 	it 'does not break with indirect circular require', (done) ->

# 		client.get 'localhost:3067/test-04.1', (res) ->
# 			if res.error
# 				return done(res.error)

# 			# console.log JSON.stringify( res.body, null, '  ' )

# 			res.header['content-type'].should.match(/application\/json/)
# 			res.body.circularAsyncData.should.have.length(1)
# 			res.body.circularAsyncData.every( (doc) -> doc.tags.some((tag)-> tag == 'omg') ).should.be.ok

# 			done()

# 	it 'does not break with direct circular require', (done) ->

# 		client.get 'localhost:3067/test-04.4', (res) ->
# 			if res.error
# 				return done(res.error)

# 			res.body.title.should.eql('Direct Circular Reference!')
# 			res.body.asyncData.title.should.eql('Direct Circular Reference!')

# 			# console.log res.body

# 			done()



# describe 'simple dynamic doc', ->

# 	it 'returns json data per request', (done) ->

# 		client.get 'localhost:3067/test-05?q=46', (res) ->
# 			if res.error
# 				return done(res.error)

# 			res.header['content-type'].should.match(/application\/json/)
# 			res.body.title.should.eql('Simple Test Dynamic Doc')
# 			res.body.q.should.eql(46)

# 			done()

# 	it 'multiple calls do not interfere', (done) ->

# 		client.get 'localhost:3067/test-05?q=01'

# 		client.get 'localhost:3067/test-05?q=23', (res) ->
# 			if res.error
# 				return done(res.error)

# 			res.header['content-type'].should.match(/application\/json/)
# 			res.body.title.should.eql('Simple Test Dynamic Doc')
# 			res.body.q.should.eql(23)

# 			done()

# 		client.get 'localhost:3067/test-05?q=02'


# describe 'simple async dynamic doc', ->

# 	it 'fetches from fsdb per request and returns json', (done) ->

# 		client.get 'localhost:3067/test-06?tag=foo', (res) ->
# 			if res.error
# 				return done(res.error)

# 			# console.log res.body.dynamicAsyncData

# 			res.header['content-type'].should.match(/application\/json/)
# 			res.body.dynamicAsyncData.should.have.length(4)
# 			res.body.dynamicAsyncData.every( (doc) -> doc.tags.some((tag)-> tag == 'foo') ).should.be.ok

# 			done()


# describe 'doc with loaded template and body and nested async dymanic layouts', ->

# 	it 'pulls itself together', (done) ->

# 		client.get 'localhost:3067/test-07', (res) ->
# 			if res.error
# 				return done(res.error)

# 			# console.log res.text

# 			$ = cheerio.load(res.text)

# 			$('#title').text().should.eql('Integrated Test')
# 			$('head title').text().should.eql('Nested Dynamic Async Layout | Integrated Test')
# 			$('ul.items').children().should.have.length(10)

# 			done()


# # describe 'doc with linked resource', ->

# # describe 'recursive load and link objects and arrays', ->













after ->
	server.close()



