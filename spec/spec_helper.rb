require 'coveralls'
Coveralls.wear!

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'redis'
require 'redis/asm'
