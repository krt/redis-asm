require 'spec_helper'
require 'json'
require 'yaml'

REDIS_PORT = ENV['REDIS_PORT'] || 6379
REDIS_HOST = ENV['REDIS_HOST'] || 'localhost'

redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)
asm = Redis::Asm.new(redis)

SKEY = 'redis:asm:testing:set'
ZKEY = 'redis:asm:testing:zset'
HKEY = 'redis:asm:testing:hash'      
LKEY = 'redis:asm:testing:list'

describe Redis::Asm do

  before :all do
    test_data = File.read(File.expand_path('../test_data.txt', __FILE__))
      .split("\n")
    i = 0
    zdata = test_data.map{|item| i += 1; [i, item]}
    i = 0
    hdata = test_data.inject({}){|ha, k| i += 1; ha.merge(i=>k)}

    redis.pipelined do |r|
      r.script :flush
      r.sadd SKEY, test_data
      r.zadd ZKEY, zdata
      r.mapped_hmset HKEY, hdata
      test_data.each{|item| r.rpush LKEY,item}
    end
  end

  after :all do
    redis.del ZKEY
    redis.del HKEY
    redis.del SKEY
    redis.del LKEY
  end

  it 'has a version number' do
    expect(Redis::Asm::VERSION).not_to be nil
  end

  it 'responds to search method' do
    expect(asm.respond_to?(:search)).to eq(true)
  end

  context 'execute fuzzy searching on Redis SET or LIST' do
    let(:result_set)  {JSON.parse(asm.search(SKEY, 'example'))}
    let(:result_list) {JSON.parse(asm.search(LKEY, 'example'))}

    it "result has exactly matched string" do
      expect(result_set.first).to eq({"haystack"=>"example", "match"=>1})
      expect(result_list.first).to eq({"haystack"=>"example", "match"=>1})
    end

    it "result has fuzzy matched string" do
      expect(result_set[1]).to eq({"haystack"=>"samples", "match"=>0.5})
      expect(result_list[1]).to eq({"haystack"=>"samples", "match"=>0.5})
    end

    it "result size must be default limit(10)" do
      expect(result_set.size).to eq 10
      expect(result_list.size).to eq 10
    end
  end

  context 'execute fuzzy searching on Redis SET or LIST using multi-byte string' do
    let(:result_set)  {JSON.parse(asm.search(SKEY, '東京都'))}
    let(:result_list) {JSON.parse(asm.search(LKEY, '東京都'))}

    it "result has exactly matched string" do
      expect(result_set.first).to eq({"haystack"=>"東京都", "match"=>1})
      expect(result_list.first).to eq({"haystack"=>"東京都", "match"=>1})
    end

    it "result has fuzzy matched string" do
      expect(result_set[1]).to eq({"haystack"=>"京都府", "match"=>0.33333333333333})
      expect(result_list[1]).to eq({"haystack"=>"京都府", "match"=>0.33333333333333})
    end

    it "result size must be matched item count" do
      expect(result_set.size).to eq 2
      expect(result_list.size).to eq 2
    end
  end

  context 'execute fuzzy searching on Redis ZSET or HASH' do
    let(:result_zset) {JSON.parse(asm.search(ZKEY, 'example'))}
    let(:result_hash) {JSON.parse(asm.search(HKEY, 'example'))}

    it "result has exactly matched string, zset has 'score' and hash has 'field'" do
      expect(result_zset.first).to eq({"haystack"=>"example", "score"=>"114", "match"=>1})
      expect(result_hash.first).to eq({"haystack"=>"example", "field"=>"114", "match"=>1})
    end

    it "result has fuzzy matched string, zset has 'score' and hash has 'field'" do
      expect(result_zset[1]).to eq({"haystack"=>"samples", "score"=>"119", "match"=>0.5})
      expect(result_hash[1]).to eq({"haystack"=>"samples", "field"=>"119", "match"=>0.5})
    end

    it "result size must be default limit(10)" do
      expect(result_zset.size).to eq 10
      expect(result_hash.size).to eq 10
    end
  end

  context 'execute fuzzy searching on Redis ZSET or HASH using multi-byte string' do
    let(:result_zset) {JSON.parse(asm.search(ZKEY, '東京都'))}
    let(:result_hash) {JSON.parse(asm.search(HKEY, '東京都'))}

    it "result has exactly matched string, zset has 'score' and hash has 'field'" do
      expect(result_zset.first).to eq({"haystack"=>"東京都", "score"=>"126", "match"=>1})
      expect(result_hash.first).to eq({"haystack"=>"東京都", "field"=>"126", "match"=>1})
    end

    it "result has fuzzy matched string, zset has 'score' and hash has 'field'" do
      expect(result_zset[1]).to eq({"haystack"=>"京都府", "score"=>"125", "match"=>0.33333333333333})
      expect(result_hash[1]).to eq({"haystack"=>"京都府", "field"=>"125", "match"=>0.33333333333333})
    end

    it "result size must be matched item count" do
      expect(result_zset.size).to eq 2
      expect(result_hash.size).to eq 2
    end
  end

end
