# Redis::Asm

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

To initialize `Redis::Asm` with host and port:
```ruby
redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)
asm = Redis::Asm.new(redis)
```
To execute fuzzy search from Redis collections:
```ruby
require 'json'
require 'yaml'

# asm.search(KEY, NEELDE, MAX_RESULTS=10)

# To search from SET or LIST

result = asm.search(SET_OR_LIST_KEY, 'example')
puts JSON.parse(result).to_yaml
# ---
# - haystack: example
#   match: 1
# - haystack: samples
#   match: 0.5
# - haystack: abampere
#   match: 0.42857142857143
.
.

# To search from HASH

# Redis::Asm matches HASH values
# each item has 'field' property

result = asm.search(HASH_KEY, '東京都')
puts JSON.parse(result).to_yaml
# ---
# - haystack: "東京都"
#   field: '126'
#   match: 1
# - haystack: "京都府"
#   field: '125'
#   match: 0.33333333333333

# To search from ZSET
# each item has 'score' property

result = asm.search(ZSET_KEY, '東京都')
puts JSON.parse(result).to_yaml
# ---
# - haystack: "東京都"
#   score: '126'
#   match: 1
# - haystack: "京都府"
#   score: '125'
#   match: 0.33333333333333
```
## Performance

 - PC: MBP 2.6 GHz Intel Core i5 16GM DD3 RAM
 - OS: Mac OSX 10.9.5
 - ruby 2.1.5p273 [x86_64-darwin13.0]
 - Redis server v=2.6.17 bits=64

```bash
# search from 10,000 items of SETS
# each item contains UTF-8 characters, and consists of between 1 and 30 chars.
% ruby search_bench.rb stone
      user     system      total        real
  0.000000   0.000000   0.000000 (  0.038567)
% ruby search_bench.rb 東京都
      user     system      total        real
  0.000000   0.000000   0.000000 (  0.022540)

% ruby search_bench.rb 弊社といたしましては
      user     system      total        real
  0.000000   0.000000   0.000000 (  0.063109)
```

Also you can try benchmarking `Redis::Asm` running `bench/bench.rb` in console.  
That's the result I've got on my machine.
```sh
krt@mbp% ruby bench.rb
                             user     system      total        real
          a :   1000 wd  0.000000   0.000000   0.000000 (  0.003485)
          a :  10000 wd  0.000000   0.000000   0.000000 (  0.025130)
          a : 100000 wd  0.000000   0.000000   0.000000 (  0.213464)
          
        baz :   1000 wd  0.000000   0.000000   0.000000 (  0.010732)
        baz :  10000 wd  0.000000   0.000000   0.000000 (  0.073628)
        baz : 100000 wd  0.000000   0.000000   0.000000 (  0.565700)
        
    rifmino :   1000 wd  0.000000   0.000000   0.000000 (  0.014601)
    rifmino :  10000 wd  0.000000   0.000000   0.000000 (  0.082726)
    rifmino : 100000 wd  0.000000   0.000000   0.000000 (  0.680512)
    
mskelngesol :   1000 wd  0.000000   0.000000   0.000000 (  0.014717)
mskelngesol :  10000 wd  0.000000   0.000000   0.000000 (  0.086301)
mskelngesol : 100000 wd  0.000000   0.000000   0.000000 (  0.623105)
```
*To be fair,* it's suitable for less or eql than about 10,000 words, for Redis blocks it's requests while executing Lua script.


## Contributing

1. Fork it ( https://github.com/krt/redis-asm/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
