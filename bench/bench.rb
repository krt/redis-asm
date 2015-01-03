#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'benchmark'
require 'redis'
require 'redis-asm'
require 'json'

dic = 
  File.read(File.expand_path('../words.txt', __FILE__)).
  split("\n").
  map(&:chomp)
3.times{dic.shift}

SKEY = 'redis:asm:bench'

def setup_redis key, dic, haystack_size
  diviser = dic.size / haystack_size
  r = Redis.current
  r.del key
  r.sadd key, dic.select.with_index {|w, i| i % diviser == 0 }
end

r = Redis.current
asm = Redis::Asm.new(r)

needles = %w(a baz rifmino mskelngesol 元気です)

Benchmark.bm(22) do |x|
  needles.each do |needle|
    [1000, 10000, 100000].each do |s|
      setup_redis SKEY, dic, s
      x.report("%11s : %6d wd"%[needle, s]) { asm.search(SKEY, needle) }
    end
    puts ""
  end
end

# output results
# puts "results from 100000\n"
# setup_redis SKEY, dic, 100000
# needles.each do |needle|
#   puts "#{needle} :"
#   p JSON.parse(asm.search(SKEY, needle))
#   puts ""
# end
