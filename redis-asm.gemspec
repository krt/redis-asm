# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redis/asm/version'

Gem::Specification.new do |spec|
  spec.name          = "redis-asm"
  spec.version       = Redis::Asm::VERSION
  spec.authors       = ["Masato Yamaguchi"]
  spec.email         = ["karateka2000@gmail.com"]
  spec.summary       = "Fast fuzzy string search on Redis using Lua. UTF-8 ready."
  spec.description   = "Fast ASM (Approximate String Matching) by calucuating edit distance within the collecitons such as ZSET, HASH, LIST, SET on Redis using Lua script. It provides you to search multi-byte characters correctly, because it recognizes lead-byte of UTF-8 strings."
  spec.homepage      = "http://github.com/krt/redis-asm"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_dependency 'redis', '~> 3.0'
  spec.add_dependency 'digest/sha1'
end
