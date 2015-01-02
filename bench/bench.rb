#!/usr/bin/env ruby
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'benchmark'
require 'redis'
require 'redis-asm'

dic = 
  File.read(File.expand_path('../words.txt', __FILE__)).
  split("\n").
  map(&:chomp)
dic.shift

SKEY = 'redis:asm:bench'

def setup_redis key, dic, haystack_size
  diviser = dic.size / haystack_size
  r = Redis.current
  r.del key
  r.sadd key, dic.select.with_index {|w, i| i % diviser == 0 }
end

r = Redis.current
asm = Redis::Asm.new(r)

needles = %w(a baz rifmino mskelngesol)

Benchmark.bm(22) do |x|
  needles.each do |needle|
    [1000, 10000, 50000, 100000].each do |s|
      setup_redis SKEY, dic, s
      x.report("%11s : %6d wd"%[needle, s]) { asm.search(SKEY, needle) }
    end
  end
end







