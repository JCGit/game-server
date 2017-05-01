local roomconstant = require "qgwroom.constant"
local inspect = require "inspect"
local utils = require "utils"

local ALL_CARDS  = roomconstant.ALL_CARDS

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

local function cardCheck(card_set)
  if #card_set > 4 or #card_set == 1 then
    return false
  end
  
  local card_type = {
    [2]= "PAIR";
    [3] = "THREE";
    [4] = "FOUR";
  }
  
  local index = true
  local prev = nil

  for _,c in ipairs(card_set) do
    if not prev then
      prev = c
    else
      if c[2] ~= prev[2] then
        index = false
      end
    end
  end

  if index then
    return "ok", card_type[#card_set]
  else
    return "card_wrong_type"
  end
end

--转换成cardSet
local function getCardSet(cards)
   local card_set = {}
    table.sort(cards, function (a, b) 
        if a > b then
          return true
        end
      end)
    for _, v in ipairs(cards) do
      table.insert(card_set, ALL_CARDS[v])
    end
    return card_set
end

local function get_card_type(card_set)
  local cardNum = #card_set
  local ret, card_type
  
  if cardNum == 1 then
    ret = "ok"
    card_type = "SINGLE" 
  elseif cardNum > 1 then
    ret,card_type = cardCheck(card_set)
  end 

  return ret, card_type 
end

function M.compare(cards, prevCardType, prevCard)
  
  local card_set = getCardSet(cards)
  
  local ret, card_type = get_card_type(card_set)

  if not prevCard then

    if ret then
      return ret, card_type 
    else
      return "card_wrong_type"
    end
  else
    if #cards < #prevCard then
      return "card_not_bigger"
    end
    
    local prevCardSet = getCardSet(prevCard)
     
    if #cards ~= #prevCard then
      return "card_wrong_type"
    end
    if prevCardType == "SINGLE" then
      if cards[1] >  prevCard[1] then
        return "ok", "SINGLE"
      else
        return "card_not_bigger"
      end
    else
      if ret and card_type == prevCardType then
        if card_set[1][3] > prevCardSet[1][3] and card_set[1][2] ~= prevCardSet[1][2] then
          return "ok", card_type
        else
          return "card_not_bigger"
        end
      else
        return "card_wrong_type"
      end
    end
  end

end

function M.getScore(cards)

  local cardSet = getCardSet(cards)
  local score = 0
  for _,c in ipairs(cardSet) do
    if c[2] == 10 or c[2] == 13 then
      score = score + 10
    elseif c[2] == 5 then
      score = score + 5
    end
  end
  return score
end


function M.searchCard(cards, prevCardType, prevCard)
  if #cards < #prevCard then
    return "card_not_bigger"
  end

  local CardSet = {}

  if prevCardType == "SINGLE" then
    for _,c in ipairs(cards) do 
      if c > prevCard[1] then
        table.insert(CardSet, {c})
      end
    end
  else
    local card_set = getCardSet(cards)
    local prevCardSet = getCardSet(prevCard)

    local function groups(cardset)
      local g = {}
      local len = #cardset
   
      local cursor = 0
      while cursor < len do
        cursor = cursor + 1
        local t = {}
        local prev = prev or cardset[cursor][2]
        table.insert(t, cardset[cursor][3])

        local step = 0
        for j = cursor + 1, len do 
          if prev == cardset[j][2] then
            table.insert(t, cardset[j][3])
            step = step + 1
          else
            prev = nil
            break
          end 
        end 

        cursor = cursor + step 
        table.insert(g, t)
      end
      return g
    end

    local group = groups(card_set)
    for _,g in ipairs(group) do
      if #g >= #prevCardSet then
        local gs = getCardSet(g)
        if gs[1][3] > prevCardSet[1][3] and gs[1][2] ~= prevCardSet[1][2] then
          local t = {}
          table.move(g, 1, #prevCardSet, 1, t)
          table.insert(CardSet, t)
        end 
      end
    end
  end
  
  if #CardSet > 0 then
    return "ok", CardSet, prevCardType
  else
    return "card_not_bigger"
  end
end

return M