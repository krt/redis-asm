--[[

redis_asm.lua
approximate string matching for redis

Copyright (c) 2015 Masato Yamaguchi

This software is released under the MIT License.

http://opensource.org/licenses/mit-license.php


USAGE:
> eval "(content of this script)" 1 KEY NEEDLE MAX_RESULTS

@param {string} KEY           Name of key. Accepts ZSET, SET, HASH and LIST.
@param {string} NEEDLE        Search word.
@param {boolean} MAX_RESULTS  Max size of results, defaults 10.
@return {string}              Result as json string.
]]

local i
local haystacks = {}
local opt_data  = {} -- score for ZSET, or field for HASH.

local key_type  = redis.call('TYPE', KEYS[1])["ok"]

if not key_type then return nil end
if key_type == 'zset' then
  local zset = redis.call('ZRANGE', KEYS[1], 0, -1, 'WITHSCORES')
  local is_value = true
  for i = 1, #zset do
    if     is_value then haystacks[#haystacks + 1] = zset[i] end
    if not is_value then opt_data[#opt_data + 1]   = zset[i] end
    is_value = not is_value
  end
elseif key_type == 'list' then
  haystacks = redis.call('LRANGE', KEYS[1], 0, -1)
elseif key_type == 'set' then
  haystacks = redis.call('SMEMBERS', KEYS[1])
elseif key_type == 'hash' then
  local hash = redis.call('HGETALL', KEYS[1])
  local is_field = true
  for i = 1, #hash do
    if     is_field then opt_data[#opt_data + 1]   = hash[i] end
    if not is_field then haystacks[#haystacks + 1] = hash[i] end
    is_field = not is_field
  end
else
  return nil
end

local needle = ARGV[1]
if not needle then return nil end

local max_results = tonumber(ARGV[2]) or 10

local cjson = cjson
local s_byte = string.byte
local s_sub = string.sub
local s_find = string.find
local m_min = math.min
local m_max = math.max
local m_floor = math.floor
local m_ceil = math.ceil
local t_sort = table.sort


-- mapping utf-8 leading-byte to byte offset
local byte_offsets = {
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1,
1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3,
3, 3, 3, 3, 3, 3, 3}

--[[
* Split utf-8 string into multi-byte chunks according to its leading-byte.
* @param {string}
* @return {Array.<string>} Array of multi-byte strings.
--]]
local function split_into_utf8_bytes(str)
  local codes = {}
  local i
  local offset = 0

  local mb_str, byte, offset_pos

  for i = 1, #str do
    offset_pos = i + offset
    if offset_pos >= #str then
      break
    end

    byte = byte_offsets[s_byte(str, offset_pos, offset_pos)] or 0
    
    mb_str = s_sub(str, offset_pos, offset_pos + byte)
    codes[#codes + 1] = mb_str
    offset = offset + byte
  end
  return codes
end

--[[
* Check if haystack includes any character in needle.
* @param {string}
* @param {Array.<string>}
* @return {boolean} true if haystack includes utf_needle
--]]
local function haystack_includes_needle_char(haystack, utf_needle)
  for i = 1, #utf_needle do
    if s_find(haystack, utf_needle[i]) then return true end
  end
  return false
end

local cache = {}

--[[
* Calculate match score using levenshtein distance.
* @param {Array.<string>} haystack
* @param {Array.<string>} needle
* @param {boolean} if true, stop calculating 
                   when the result might be lower than lowest_score
* @param {number|nil} lowest_score
* @return {number|nil} match score(0..1)
--]]
local function levenshtein_score(str, needle, should_cutoff, lowest_score)
  local length, length_needle, code, result, should_break
  local distance, distance_needle, index, index_needle, cutoff_distance
  local longer_length = m_max(#str, #needle)

  if should_cutoff and lowest_score then
    cutoff_distance = m_ceil((1 - lowest_score) * longer_length) + 1
  end

  length = #str
  length_needle = #needle
  for index = 1, length do
    cache[index] = index + 1
  end

  for index_needle = 1, length_needle do
    code = needle[index_needle]
    result = index_needle - 1
    distance = index_needle - 1

    for index = 1, length do
      distance_needle = (code == str[index]) and distance or distance + 1
      distance = cache[index]
      result = (distance > result) and
        ((distance_needle > result) and result + 1 or distance_needle)
        or
        ((distance_needle > distance) and distance + 1 or distance_needle)
      cache[index] = result

      if cutoff_distance and result > cutoff_distance then
        return nil
      end
    end
  end
  return 1 - (result / longer_length)
end

local scores = {}
local utf_needle = split_into_utf8_bytes(needle)
local lowest_score, utf_word, longer_length, score
local should_cutoff = false

-- main loop.
for i = 1, #haystacks do
  if haystack_includes_needle_char(haystacks[i], utf_needle) then
    utf_word = split_into_utf8_bytes(haystacks[i])
    
    if #utf_word >= #utf_needle then
      longer_length = #utf_word

      if s_find(haystacks[i], needle) then
        score = #utf_needle * (1 / longer_length)
      else
        score = levenshtein_score(utf_word, utf_needle, should_cutoff, lowest_score)
      end

      if score and not(score == 0) then
        if #scores > max_results then
          should_cutoff = true
          t_sort(
            scores,
            function(a,b)
              return a.score > b.score
            end
          )
          lowest_score = scores[max_results].score
          if score > lowest_score then
            scores[#scores + 1] = {score = score, idx = i}
          end
        else
          scores[#scores + 1] = {score = score, idx = i}
        end
      end
    end
  end

end

t_sort(
  scores,
  function(a,b)
    return a.score > b.score
  end
)

local result = {}
local output_length = m_min(#scores, max_results)

for i = 1, output_length do
  local item = {}
  item['match'] = scores[i].score
  item['haystack'] = haystacks[scores[i].idx]
  if key_type == 'zset' then
    item['score'] = opt_data[scores[i].idx]
  elseif key_type == 'hash' then
    item['field'] = opt_data[scores[i].idx]
  end
  result[#result + 1] = item
end

local text = cjson.encode(result)

return(text)

