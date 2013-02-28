# Makefile to build courtesy of coffee-resque
# https://github.com/technoweenie/coffee-resque/blob/master/Makefile
generate-js: deps
	@find src -name '*.coffee' | xargs coffee -c -o lib

remove-js:
	@rm -fr lib/

deps:
	@test `which coffee` || echo 'You need to have CoffeeScript in your PATH.\nPlease install it using `npm install coffee-script`.'

test: deps
	@find test -name '*_test.coffee' | xargs -n 1 -t echo

dev: generate-js
	@coffee -wc --no-wrap -o lib src/*.coffee

.PHONY: all