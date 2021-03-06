###*
 * This is a example of how to use `kit.all` to deal with the
 * classic producer-consumer problem.
 *
 * Of cause, most times `kit.all` is used with a fixed array, this is a complex
 * usage of it.
###

kit = require '../lib/kit'

# Max running threads at the same time.
maxProducer = 5
maxConsumer = 2

regexUrl = /<a[\w\s]+href="(http.+?)"/g

launch = ->
	# The producer and the comsumer will create
	# an infinity life circle.
	kit.all [
		kit.all maxProducer, producer, false
		kit.all maxConsumer, consumer, false
	]
	.catch (err) ->
		kit.err err.message

# Broker handles the orders and products.
broker = {
	orders: ['http://www.baidu.com']
	products: []

	order: (urls) ->
		if urls
			broker.orders = broker.orders.concat urls
		else
			broker.orders.pop()

	product: (page) ->
		if page
			broker.products.push page
		else
			broker.products.pop()
}

# Producer will download a page and add it to the store.
producer = ->
	url = broker.order()

	return kit.sleep 200 if not url # Nothing to work, wait.

	kit.logs 'producing:', url
	kit.request(url).then broker.product

# Comsumer will parse a page and find some urls in the page,
# then add the urls to the tasks.
consumer = ->
	page = broker.product()

	return kit.sleep 200 if not page # Nothing to consume, wait.

	# Find url in page.
	urls = kit.regexMap regexUrl, page, 1

	# Randomly get 3 urls.
	broker.order kit._.sample(urls, 3)


launch()
