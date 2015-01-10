# Redis::Asm
[![Build Status](https://travis-ci.org/krt/redis-asm.svg?branch=master)](https://travis-ci.org/krt/redis-asm)
[![Coverage Status](https://img.shields.io/coveralls/krt/redis-asm.svg)](https://coveralls.io/r/krt/redis-asm)

##### Fast fuzzy string search on Redis using Lua. UTF-8 ready.

## Description
Fast ASM (Approximate String Matching) by calculating edit distance within the collections such as ZSET, HASH, LIST, SET on Redis using Lua script.  
`Redis::Asm` provides you to search multi-byte characters correctly, because it recognizes lead-byte of UTF-8 strings.

## Prerequisites
This library requires a Redis server with Lua scripting support (EVAL and EVALSHA commands). This support was added in Redis 2.6.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'redis-asm'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redis-asm

## Usage

To initialize `Redis::Asm`:
```ruby
require 'redis'
require 'redis-asm'

# Use Redis.current:
redis = Redis.current

# Initialize Redis with host and port:
redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)

asm = Redis::Asm.new(redis)
```


First, prepare test data:
```ruby
data = %w(example samples abampere zzi 東京都 京都府)

# key names
keys = {}
types = ['set', 'zset', 'hash', 'list']
types.each{|t| keys[t] = "testdata:#{t}"}

# reset Redis
keys.values.each{|v| redis.del v }

# set data to Redis
redis.sadd         keys['set'],  data
redis.zadd         keys['zset'], data.map.with_index{|d, i| [i+1, d]} 
redis.mapped_hmset keys['hash'], ({}).tap{|h| data.each_with_index{|x,i| h[i+1] = x}}
data.each{|d| redis.rpush keys['list'], d }
```

To execute fuzzy search from Redis collections:
```ruby
require 'json'
require 'yaml'

# asm.search(KEY, NEELDE, MAX_RESULTS=10)

# To search from SET
result = asm.search(keys['set'], 'example')
# To search from LIST
result = asm.search(keys['list'], 'example')

puts JSON.parse(result).to_yaml
# ---
# - haystack: example
#   match: 1
# - haystack: samples
#   match: 0.57142857142857
# - haystack: abampere
#   match: 0.5

# To search from HASH

# Redis::Asm matches HASH values
# each item has 'field' property

result = asm.search(HASH_KEY, 'example')
puts JSON.parse(result).to_yaml
# ---
# - haystack: example
#   field: '1'
#   match: 1
# - haystack: samples
#   field: '2'
#   match: 0.57142857142857
# - haystack: abampere
#   field: '3'
#   match: 0.5

# To search from ZSET
# each item has 'score' property

result = asm.search(ZSET_KEY, 'example')
puts JSON.parse(result).to_yaml
# ---
# - haystack: example
#   score: '1'
#   match: 1
# - haystack: samples
#   score: '2'
#   match: 0.57142857142857
# - haystack: abampere
#   score: '3'
#   match: 0.5
```
You can use UTF-8 multibyte chars:
```ruby
result = asm.search(ZSET_KEY, '東京都')
puts JSON.parse(result).to_yaml
# ---
# - haystack: "東京都"
#   match: 1
# - haystack: "京都府"
#   match: 0.33333333333333
```
## Performance

 - PC: MBP 2.6 GHz Intel Core i5 16GM DD3 RAM
 - OS: Mac OSX 10.9.5
 - Ruby 2.1.5p273 [x86_64-darwin13.0]
 - Redis server v=2.6.17 bits=64

You can try benchmarking `Redis::Asm` by running `rake bench` in console.  
That's the result I've got on my machine.
```sh
krt@mbp% ruby bench/bench.rb
                             user     system      total        real
          a :   1000 wd  0.000000   0.000000   0.000000 (  0.016898)
          a :  10000 wd  0.000000   0.000000   0.000000 (  0.165706)
          a : 100000 wd  0.000000   0.000000   0.000000 (  1.468973)

        baz :   1000 wd  0.000000   0.000000   0.000000 (  0.014015)
        baz :  10000 wd  0.000000   0.000000   0.000000 (  0.091153)
        baz : 100000 wd  0.000000   0.000000   0.000000 (  0.651317)

    rifmino :   1000 wd  0.000000   0.000000   0.000000 (  0.017831)
    rifmino :  10000 wd  0.000000   0.000000   0.000000 (  0.108233)
    rifmino : 100000 wd  0.000000   0.000000   0.000000 (  0.772444)

mskelngesol :   1000 wd  0.000000   0.000000   0.000000 (  0.015920)
mskelngesol :  10000 wd  0.000000   0.000000   0.000000 (  0.092513)
mskelngesol : 100000 wd  0.000000   0.000000   0.000000 (  0.701796)

       元気です :   1000 wd  0.000000   0.000000   0.000000 (  0.002177)
       元気です :  10000 wd  0.000000   0.000000   0.000000 (  0.028857)
       元気です : 100000 wd  0.000000   0.000000   0.000000 (  0.279001)
```
*NOTE:* To be fair, it's suitable for less or eql than about 10,000 words, for Redis blocks it's requests while executing Lua script.

## Acknowledgment

 - Words in test data from @atebits  
https://github.com/atebits/Words  
 - Some japanese multibyte words from @gkovacs  
https://github.com/gkovacs/japanese-morphology
 - Levenshtein algorythm from @wooorm  
https://github.com/wooorm/levenshtein-edit-distance

## Contributing

1. Fork it ( https://github.com/krt/redis-asm/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
