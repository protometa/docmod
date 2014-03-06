
fs = require 'fs'
http = require 'http'
superagent = require 'superagent'
should = require 'should'
cheerio = require 'cheerio'
st = require 'st'

Doc = require '../doc'

connect = require 'connect'

docpad = require 'docpad-redux'
config = require './config'

app = connect()

app.use(docpad(config))
app.use(st(config.out))

server = http.createServer(app).listen(3067);

describe 'docpad redux doc', ->

    it 'returns Doc with metadata using cb', (done) ->

        doc = new Doc('./test/src/docs/testdoc01.html.md')

        doc.getMeta (err,meta) ->
            should.exist(meta)
            meta.should.have.property('title','Test Doc')

            done()

    it 'returns Doc with metadata using promise', (done) ->

        doc = new Doc('./test/src/docs/testdoc01.html.md')

        doc.getMeta().then (meta) ->
            should.exist(meta)
            meta.should.have.property('title','Test Doc')

        .done ->
            done()

describe 'fsdb with docpad redux doc matching function', ->

    it 'returns doc with given url'





describe 'server with docpad-redux middleware', ->

    it 'responds', (done) ->

        superagent.get 'localhost:3067', (res) ->
            should.exist(res)
            done()

    it 'returns our rendered test doc', (done) ->

        superagent.get 'localhost:3067/testdoc01.html.md', (res) ->
            should.exist(res)
            if res.error then return done(res.error)

            $ = cheerio.load(res.text)
            $('#title').text().should.eql( 'Test Site' )

            done()

after ->
    server.close()



