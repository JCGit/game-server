local game_constant = require "dnroom.constant"
local inspect = require "inspect"

local CARD_TYPES = game_constant.CARD_TYPES
local ALL_CARDS  = game_constant.ALL_CARDS

local M = {}

function M.bubble_sort(list, comp)
  for i = 1, # list do
    local stop = true
    for j = # list, i + 1, -1 do
      local k = j - 1
      local lj, lk = list[j], list[k]
      if comp(lj, lk) then
        stop, list[j], list[k] = false, lk, lj
      end
    end
    if stop then break end
  end
end

function M.contains(list, l)
  for _, v in ipairs(l) do
    local contain = false
    for _, vn in ipairs(list) do
      if v == vn then
        contain = true
        break
      end
    end
    if not contain then
      return false
    end
  end
  return true
end

function M.remove_sublist(list, sublist)
  for i, v in ipairs(sublist) do
    for j, u in ipairs(list) do
      if v == u then
        table.remove(list, j)
        break
      end
    end
  end
end

function M.shuffle_card(seed, n)
  math.randomseed(seed)
  local list = {}
  for i=1, n do
    list[i] = i
  end
  for i=1, n do
    local ri = math.random(n)
    list[ri], list[i] = list[i], list[ri]
  end
  return list
end

local NIU_TYPE = {
  NIU_NIU = 5,
  NIU_FULL = 4,
  NIU_TEN = 3,
  NIU_NINE = 2,
  NIU_SMALL = 1,
}
 
--冒泡排序
local function bubble_sort(set, cmp)
  for i=1, i < #set do
    for j=i, j < #set do
      if cmp(set[j] , set[j+1]) then
        set[i], set[j] = set[j], set[i]
      end
    end
  end
end

local function sort_card(card)
  local card_set = {}
  table.sort(card)
  for _, v in ipairs(card) do
    table.insert(card_set, ALL_CARDS[v])
  end
  return card_set
end

function M.get_niu_type(card)
  assert(#card == 3, "card num invalid")
  local set = sort_card(card)
  local sum = 0
  local same = true
  local morethan_eleven = true

  local prev = set[1][2]
  for _,v in ipairs(set) do
    local val = v[2]
    if prev ~= val then   --计算相同牌
      same = false
    end
    prev = val

    if val < 11 then  --计算是否是 J,Q,K
      morethan_eleven = false
    end
    val = ( val > 10 ) and 10 or val 
    sum = sum + val
    sum = ( sum > 10 ) and sum%10 or sum  --计算牛值
  end

  sum = sum % 10

  local card_type
  if sum ~= 0 then
    if sum ~= 9 then
      card_type = NIU_TYPE.NIU_SMALL
    else
      card_type = NIU_TYPE.NIU_NINE
    end
  else
    if morethan_eleven and same then
      card_type = NIU_TYPE.NIU_NIU
    elseif morethan_eleven then
      card_type = NIU_TYPE.NIU_FULL
    else
      card_type = NIU_TYPE.NIU_TEN
    end
  end
  return card_type, sum, set  
end

local COMPARE_TYPE = {
  WIN="WIN",
  TIE="TIE",
  LOSE="LOSE",
}

function M.compare(ResultA,ResultB, dealer_flag, dealer_min)
  repeat
    if ResultA.type > ResultB.type then
      result_type = COMPARE_TYPE.WIN
      break
    end

    if ResultA.type < ResultB.type then
      result_type = COMPARE_TYPE.LOSE
      break
    end

    -- tie
    if ResultA.type ~= NIU_TYPE.NIU_SMALL then
      --没有等于的情况
      if ResultA.set[3][3] > ResultB.set[3][3] then
        result_type = COMPARE_TYPE.WIN
      else 
        result_type = COMPARE_TYPE.LOSE
      end
      break
    end

    --设置了庄家最小点，就去庄家最小点,做比较
    if dealer_flag and dealer_min then
      if ResultB.sum < dealer_min then
        ResultB.sum = dealer_min
      end
    end

    if ResultA.type == NIU_TYPE.NIU_SMALL then
      if ResultA.sum > ResultB.sum then
        result_type = COMPARE_TYPE.WIN
      elseif ResultA.sum < ResultB.sum then
        result_type = COMPARE_TYPE.LOSE
      else
        if ResultA.set[3][3] > ResultB.set[3][3] then
           result_type = COMPARE_TYPE.WIN
        else 
           result_type = COMPARE_TYPE.LOSE
        end
        --result_type = COMPARE_TYPE.TIE
      end
      break
    end
  until(true)
  return result_type
end

return M