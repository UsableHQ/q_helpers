# q_helpers.coffee
#
# helper functions to work with the Q promises library.

Q       = require 'q'
_       = require 'underscore'

###
return a function that takes a standard node function and makes it work like a Q promise.

essentialy, this just calls bind.
###
exports.QifyFn = _QifyFn = (fn) ->
  return Q.nbind(fn, fn)

###
Take a Q promise and convert it into a node style callback function.

Note, that code shouldn't keep switching between the two styles as the
unIfyFn() looks quite expensive.
###
exports.unQifyFn = (args..., promise_fn) ->
  want_array = false
  if args.length > 0 and args[0] == 'array' then want_array = true
  if not _.isFunction promise_fn then throw new Error("to Unqify - promise_fn not defined")
  return (args..., callback) ->
    if not(_.isFunction callback) then throw new Error("callback not supplied to Qunified function: " + promise_fn.name)
    Q.when(Q.apply(promise_fn, promise_fn, args))
      # promise succeeds
    .then (results) ->
      if not results? then results = []
      if not _.isArray results then results = [ results ]
      if want_array then results = [ results ]
      results.unshift null
      callback.apply callback, results
    # promise fails.
    .fail (err) ->
      callback err
    .end()

###
call a node funtion with args and return the promise for it.

This is essentially like ncall(...) BUT doesn't need you to
specify the function binding, which is bound to the function name being
called.
###
exports.ncall_fn = (fn, args...) ->
  qfn = _QifyFn fn
  return qfn.apply qfn, args


###
whilePromise(test_fn, loop_promise_fn)

Execute a while.  Run test_fn() and if true then call the loop_promise_fn().
After the promise has resolved, then run the test_fn() again and repeat
until the test_fn() returns false.
###
exports.whilePromise = whilePromise = (test_fn, loop_promise_fn) ->
  _iterator_helper_Promise = ->
    if test_fn.call()
      Q.when(loop_promise_fn.call())
      .then ->
        _iterator_helper_Promise()
  return Q.when(_iterator_helper_Promise())


###
map an array of things with a promise function.

The promise function takes one parameter from the array.  The results of calling the
promise function are then pushed to array.  Returns a promise.
###
exports.mapPromise = mapPromise = (array, promiseFn) ->
  results = []
  index = 0
  if not _.isArray array then return Q.reject new Error 'No array passed to q_helpers.mapPromise()'
  whilePromise(
    -> index < array.length

    -> Q.when(promiseFn.call(promiseFn, array[index])).then( (result) -> results.push result; index += 1)
    ).then( -> return results )


exports.mapParallelPromise = mapParallelPromise = (array, promiseFn) ->
  if not _.isArray array then return Q.reject new Error 'No array passed to q_helpers.mapPromise()'
  if array.length == 0 then return Q.resolve []

  deferred = Q.defer()
  results = []
  count = 0

  for item, index in array
    do (item, index) ->
      Q.when(promiseFn.call(promiseFn, item))
      .then (result) -> 
        results[index] = result
        count += 1
        if count == array.length then deferred.resolve results
      .fail( (err) -> deferred.reject err)
      .end()

  return deferred.promise


exports.mapParallelBatchPromise = mapParallelBatchPromise = (array, batchSize, promiseFn) ->
  if not _.isArray array then return Q.reject new Error 'No array passed to q_helpers.mapPromise()'
  if array.length == 0 then return Q.resolve []

  results = []
  index = 0
  whilePromise(
    -> index < array.length

    ->
      size = if index + batchSize < array.length then batchSize else array.length - index
      mapParallelPromise(array[index...index+size], promiseFn)
      .then( (result) -> results.push.apply(results, result); index += size)
    ).then( -> results)


###
apply the same promise function to an array of values
In this case, we don't really care what the return value is, just that
we have waited until all are done in the sequence in the array.
###
exports.forEachArrayApplyPromise = forEachArrayApplyPromise = (array, promiseFn, initialValue=undefined) ->
  if not _.isArray array then throw new Error 'No array passed to q_helpers.forEachArrayApplyPromise()'
  if array.length == 0 then return Q.resolve initialValue

  result = Q.resolve initialValue
  for a in array
    do (a) ->
      result = result.then( -> promiseFn.call(promiseFn, a))
  return result


###
_chain_2_promises (f1, f2)

returns a function that takes (args...) and applies it to the two functions such that
f3(a)  === f1(a).then( (args-for-f2) -> f2(args-for-f2)

i.e. it lets you compose two promiseOrValue functions into a single one.  Note they
are closures so they can capture other arguments as required.
###
_chain_2_promises = (fn1, fn2) ->
  if not _.isFunction fn1 then throw Error("#{fn1} is not a function")
  if not _.isFunction fn2 then throw Error("#{fn2} is not a function")
  return (args1...) ->
    Q.when(Q.apply fn1, fn1, args1).then( (args2...) -> Q.apply fn2, fn2, args2)


###
chain_n_promises (fns...)

returns a single function that chains the entire array of fns into a single function
by recursively calling _chain_2_promises
###
exports.chain_n_promises = _chain_n_promises = (fns...) ->
  if fns.length < 2 then throw Error("Programming error: You cant chain one or less promises...")
  if fns.length == 2 then return _chain_2_promises fns[0], fns[1]
  return _chain_2_promises fns[0],
    _chain_n_promises.apply _chain_n_promises, fns[1..]
