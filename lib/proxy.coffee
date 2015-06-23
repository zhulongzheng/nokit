###*
 * For test, page injection development.
 * A cross-platform programmable Fiddler alternative.
###
Overview = 'proxy'

kit = require './kit'
{ _, Promise } = kit
http = require 'http'

proxy =

	agent: new http.Agent

	###*
	 * Http CONNECT method tunneling proxy helper.
	 * Most times used with https proxing.
	 * @param {http.IncomingMessage} req
	 * @param {net.Socket} sock
	 * @param {Buffer} head
	 * @param {String} host The host force to. It's optional.
	 * @param {Int} port The port force to. It's optional.
	 * @param {Function} err Custom error handler.
	 * @example
	 * ```coffee
	 * kit = require 'nokit'
	 * kit.require 'proxy'
	 * http = require 'http'
	 *
	 * server = http.createServer()
	 *
	 * # Directly connect to the original site.
	 * server.on 'connect', kit.proxy.connect
	 *
	 * server.listen 8123
	 * ```
	###
	connect: (req, sock, head, host, port, err) ->
		net = kit.require 'net', __dirname
		h = host or req.headers.host
		p = port or req.url.match(/:(\d+)$/)[1] or 443

		psock = new net.Socket
		psock.connect p, h, ->
			psock.write head
			sock.write "
				HTTP/#{req.httpVersion} 200 Connection established\r\n\r\n
			"

		sock.pipe psock
		psock.pipe sock

		error = err or (err, socket) ->
			cs = kit.require 'colors/safe'
			kit.log err.toString() + ' -> ' + cs.red req.url
			socket.end()

		sock.on 'error', (err) ->
			error err, sock
		psock.on 'error', (err) ->
			error err, psock

	###*
	 * A promise based middlewares proxy.
	 * @param  {Array} middlewares Each item is a function `({ req, res }) -> Promise`,
	 * or an object:
	 * ```coffee
	 * {
	 * 	url: String | Regex
	 * 	headers: String | Regex
	 * 	method: String | Regex
	 * 	handler: ({ body, req, res, next, url, headers, method }) -> Promise
	 * }
	 * ```
	 * The `url`, `headers` and `method` are act as selectors. If current
	 * request matches the selectors, the `handler` will be called with the
	 * matched result. If the handler has async operation inside, it should
	 * return a promise.
	 * @return {Function} `(req, res) -> Promise` The http request listener.
	 * ```coffee
	 * proxy = kit.require 'proxy'
	 * Promise = kit.Promise
	 * http = require 'http'
	 *
	 * routes = [
	 * 	->
	 * 		# Record the time of the whole request
	 * 		start = new Date
	 * 		this.next => kit.sleep(300).then =>
	 * 			this.res.setHeader 'x-response-time', new Date - start
	 * 	->
	 * 		kit.log 'access: ' + this.req.url
	 * 		# We need the other handlers to handle the response.
	 * 		kit.sleep(300).then => this.next
	 * 	{
	 * 		url: /\/items\/(\d+)/
	 * 		handler: -> kit.sleep(300).then =>
	 * 			this.body = { id: this.url[1] }
	 * 	}
	 * 	]
	 *
	 * http.createServer proxy.mid(routes)
	 * .listen 8123
	 * 	 * ```
	###
	mid: (middlewares) ->
		Stream = require 'stream'

		match = (self, obj, key, pattern) ->
			return true if pattern == undefined

			ret = if _.isString pattern
				if _.startsWith(obj[key], pattern)
					obj[key]
			else if _.isRegExp pattern
				obj[key].match pattern
			else if _.isFunction pattern
				pattern obj[key]

			if ret != undefined
				self[key] = ret

		matchObj = (self, obj, key, target) ->
			return true if target == undefined

			ret = {}

			for k, v of target
				return false if not match ret, obj[key], k, v

			self[key] = ret
			return true

		next = (fn) ->
			return next if not fn
			@nextFns ?= []
			@nextFns.push fn
			return next

		endRes = (res, body) ->
			switch typeof body
				when 'string'
					res.end body
				when 'object'
					if body == null
						res.end()
					else if body instanceof Stream
						body.pipe res
					else if body instanceof Buffer
						res.end body
					else
						res.setHeader 'Content-type', 'application/json'
						res.end JSON.stringify body
				else
					res.end()

			return

		(req, res) ->
			index = 0

			self = { req, res, body: null, next }

			end = ->
				if self.nextFns
					p = Promise.resolve()
					for fn in self.nextFns
						p = p.then fn
					p.then ->
						endRes res, self.body
				else
					endRes res, self.body

				return

			iter = (flag) ->
				if flag != next
					return end()

				m = middlewares[index++]

				if not m
					res.statusCode = 404
					self.body = http.STATUS_CODES[404]
					return end()

				ret = if _.isFunction m
					m.call self
				else if match(self, req, 'method', m.method) and
				match(self, req, 'url', m.url) and
				matchObj(self, req, 'headers', m.headers)
					m.handler.call self
				else
					next

				if ret and _.isFunction(ret.then)
					ret.then iter
				else
					iter ret

				return

			iter next

			return

	###*
	 * Use it to proxy one url to another.
	 * @param {http.IncomingMessage} req Also supports Express.js.
	 * @param {http.ServerResponse} res Also supports Express.js.
	 * @param {String | Object} url The target url forced to. Optional.
	 * Such as force 'http://test.com/a' to 'http://test.com/b',
	 * force 'http://test.com/a' to 'http://other.com/a',
	 * force 'http://test.com' to 'other.com'.
	 * It can also be an url object. Such as
	 * `{ protocol: 'http:', host: 'test.com:8123', pathname: '/a/b', query: 's=1' }`.
	 * @param {Object} opts Other options. Default:
	 * ```coffee
	 * {
	 * 	# Limit the bandwidth byte per second.
	 * 	bps: null
	 *
	 * 	# if the bps is the global bps.
	 * 	globalBps: false
	 *
	 * 	agent: customHttpAgent
	 *
	 * 	# You can hack the headers before the proxy send it.
	 * 	handleReqHeaders: (headers) -> headers
	 * 	handleResHeaders: (headers) -> headers
	 * }
	 * ```
	 * @param {Function} err Custom error handler.
	 * @return {Promise}
	 * @example
	 * ```coffee
	 * kit = require 'nokit'
	 * kit.require 'proxy'
	 * kit.require 'url'
	 * http = require 'http'
	 *
	 * server = http.createServer (req, res) ->
	 * 	url = kit.url.parse req.url
	 * 	switch url.path
	 * 		when '/a'
	 * 			kit.proxy.url req, res, 'a.com', (err) ->
	 * 				kit.log err
	 * 		when '/b'
	 * 			kit.proxy.url req, res, '/c'
	 * 		when '/c'
	 * 			kit.proxy.url req, res, 'http://b.com/c.js'
	 * 		else
	 * 			# Transparent proxy.
	 * 			service.use kit.proxy.url
	 *
	 * server.listen 8123
	 * ```
	###
	url: (req, res, url, opts = {}, err) ->
		kit.require 'url'

		_.defaults opts, {
			bps: null
			globalBps: false
			agent: proxy.agent
			handleReqHeaders: (headers) -> headers
			handleResHeaders: (headers) -> headers
		}

		if not url
			url = req.url

		if _.isObject url
			url = kit.url.format url
		else
			sepIndex = url.indexOf('/')
			switch sepIndex
				# such as url is '/get/page'
				when 0
					url = 'http://' + req.headers.host + url
				# such as url is 'test.com'
				when -1
					{ path } = kit.url.parse(req.url)

					url = 'http://' + url + path

		error = err or (e) ->
			cs = kit.require 'colors/safe'
			kit.log e.toString() + ' -> ' + cs.red req.url

		# Normalize the headers
		headers = {}
		for k, v of req.headers
			nk = k.replace(/(\w)(\w*)/g, (m, p1, p2) -> p1.toUpperCase() + p2)
			headers[nk] = v

		headers = opts.handleReqHeaders headers

		stream = if opts.bps == null
			res
		else
			if opts.globalBps
				sockNum = _.keys(opts.agent.sockets).length
				bps = opts.bps / (sockNum + 1)
			else
				bps = opts.bps

			throttle = new kit.requireOptional('throttle', __dirname)(bps)

			throttle.pipe res
			throttle

		p = kit.request {
			method: req.method
			url
			headers
			reqPipe: req
			resPipe: stream
			autoUnzip: false
			agent: opts.agent
		}

		p.req.on 'response', (proxyRes) ->
			res.writeHead(
				proxyRes.statusCode
				opts.handleResHeaders proxyRes.headers
			)

		p.catch error

module.exports = proxy
