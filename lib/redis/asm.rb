require 'redis'
require "redis/asm/version"
require "digest/sha1"

class Redis
  class Asm

    SCRIPT_DIR = File.expand_path('../../', __FILE__)
    SCRIPT     = File.read File.join(SCRIPT_DIR, "redis_asm.lua")
    SHA1       = Digest::SHA1.hexdigest SCRIPT

    def initialize(redis)
      @redis = redis
    end

    def search(key, needle, max_results=10)
      @redis.evalsha(SHA1, :keys => [key], :argv => [needle, max_results])
      rescue Exception => e
        if e.message =~ /NOSCRIPT/
          @redis.eval script, :keys => [key], :argv => [needle, max_results]
        else
          raise e
      end
    end
  end
end
