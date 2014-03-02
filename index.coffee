###

    docpad async fsdb middleware
    set src, out, and config

    wrap and set async helpers
        wrapper registers call with render and returns token

    watch src/ and set changed time

    middleware

        #if req path matches doc in src/docs

            if doc is found in out (static)
                if src/ is newer than doc
                    handle doc...

                else doc in out is up to date
                    serve doc in out

            else doc is not in out
                handle doc...


        handle doc
            parse doc and get dynamic flag
            if doc is dynamic
                handle dynamic...
            else doc is static
                handle static...

        handle dynamic
            render doc...
            serve doc

        handle static
            render doc...
            save to out
            serve doc

        render doc
            render based on extentions
            on results from registered async helpers
                replace tokens with results (handlebars?)
                return rendered doc


###

url = require 'url'
fs = require 'fs'
p = require 'path'
doc = require './doc'

YAML = require 'yamljs'
metaRegex = /^\s*(([^\s\d\w])\2{2,})(?:\x20*([a-z]+))?([\s\S]*?)\1/

module.exports = (opt) ->

    src = opt.src ? './src'
    out = opt.out ? './out'

    srcPath = p.join( src,'/docs')
    console.log 'srcPath:', srcPath

    console.log srcPath

    srcmtime = new Date()

    fs.watch srcPath, () ->
        srcmtime = new Date()


    return (req, res, next) ->

        if ('GET' != req.method && 'HEAD' != req.method) then return next()

        # if req path matches doc in src/docs
        pu = url.parse(req.url)

        outPath = p.join( out, pu.path)

        # if doc is found in out (is probably static unless flag has changed)
        fs.stat outPath, (err, outStats) ->
            if err
                next(err)
            else

                # if src/ is newer than out doc
                if !outStats? or outStats.mtime.getTime() < srcmtime

                    # parse doc and get dynamic flag
                    srcDoc = new Doc(srcPath)

                    srcDoc.getMeta (err,meta) ->

                        # if doc is dynamic
                        if meta.dynamic

                            srcDoc.render (err, outRendered) ->
                                res.end(outRendered)

                        # else doc is static
                        else

                            srcDoc.render (err, outRendered) ->

                                fs.write outPath, outRendered, (err) ->
                                    next(err)

                else
                    next() # doc will be served from out



