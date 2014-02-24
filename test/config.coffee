
config = 

	template:

		site: 

			title: 'Test Site'


		async:

			featured: (cb) ->

				@findAll(( -> @featured ), cb )


			partial: (title,cb) ->

				@findOne (-> @partial && @title == title), (doc) ->
					doc.render(cb)




module.exports = config
