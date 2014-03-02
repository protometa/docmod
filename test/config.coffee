
config = 

	src: './test/src'
	out: './test/out'

	locals:

		site: 

			title: 'Test Site'


		async:

			featured: -> 
				@findAll( -> @featured )
				.then (arr) -> 
					arr.map( (e) -> e.meta() )
					q.all( arr )

			partial: (title) ->

			





module.exports = config
