local roomconstant = require "pdkroom.constant"
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

local function isBomb(groups, cardNum)
  if #groups ~= 1 or #groups[1] ~= 4 then
    return false
  else
    return true
  end
end

-- groups 整合成 out
-- last 最后一手且先手
local function isThree(groups, cardNum, out, last)
  if cardNum < 3 then
    return false
  end

  local flag = true
  local three_num = 0
  local prev
  local three = {}
  local pair = {}
  for k, v in ipairs(groups) do
    if #v == 3 then
      if prev then
        if prev == v[1][2] + 1 then
          prev = v[1][2]
          three_num  = three_num + 1
        else
          flag = false  --不连续的直接跳出
          break
        end
      else
        prev = v[1][2]
        three_num  = three_num + 1
      end

      table.insert(three, v)

    elseif #v ~= 2 and #v ~= 4 then
      flag = false
      break  --必须带对
    else
      table.insert(pair, v)
    end
  end

  if not flag then  return false end

  local remain_num = cardNum - three_num * 3 
  print("remain_num ", remain_num, three_num)
  if remain_num ~= three_num * 2 then 
    if not last then
      return false
    else
      if remain_num > three_num * 2 then
        return false
      end
    end
  end

  table.move(three, 1, #three, 1, out)
  table.move(pair, 1, #pair, #out+1, out)

  return true, three_num
end

local function isPair(groups, cardNum)
  if cardNum < 2 then return false end

  local flag = true
  local pair_num = 0
  local prev
  for k, v in ipairs(groups) do
    if #v ~= 2 then
      flag = false
      break   
    else
      if prev then
        if prev == v[1][2] + 1 then
          prev = v[1][2]
          pair_num = pair_num + 1
        else
          flag = false
          break
        end
      else
        prev = v[1][2]
        pair_num = pair_num + 1
      end 
    end  
  end

  if not flag then return false end

  if pair_num == 2 then return false end --必须3连对

  return true , pair_num
end

local function isStraight(groups, cardNum) 
  if cardNum < 3 then return false end
  local flag = true
  local seq_num = 0
  local prev 
  for k, v in ipairs(groups) do
    if #v ~= 1 then
      flag = false
      break   
    else
      if prev then
        if prev == v[1][2] + 1 then
          prev = v[1][2]
          seq_num = seq_num + 1
        else
          flag = false
          break
        end
      else
        prev = v[1][2]
        seq_num = seq_num + 1
      end
    end  
  end

  if not flag then return false end

  return true
end

local function isSingle(groups, cardNum)
  if cardNum ~= 1 then return false end

  return true
end

local function isFour(groups, cardNum, out)
  if cardNum ~= 5 then
    return false
  end

  local four
  local single
  for k, v in ipairs(groups) do
    if #v == 4 then
      four = v
    elseif #v == 1 then
      single = v    --必须带单
    else
      break  
    end
  end

  if not single or not four then  return false end

  table.move(four, 1, #four, 1, out)
  table.move(single, 1, #single, #out+1, out)

  return true
end

local CARD_TYPE = {
  Bomb       = "BOMB", 
  Plane       = "PLANE",  -- 飞机的比较算法跟三带对用一个算法
  Three       = "THREE",
  Straight    = "STRAIGHT",
  Pairs       = "PAIRS",
  Pair        = "PAIR",
  Four        = "FOUR", --四带一
  Single      = "SINGLE",
}

local CARD_TYPE_CHECKER = {
  BOMB      = { name = "BOMB",        func = isBomb},   
  THREE     = { name = "THREE",       func = isThree},
  STRAIGHT  = { name = "STRAIGHT",    func = isStraight},
  PAIR      = { name = "PAIR",        func = isPair},
  FOUR      = { name = "FOUR",        func = isFour},
  SINGLE    = { name = "SINGLE",      func = isSingle},
}

local CHECKER = {
  CARD_TYPE_CHECKER.BOMB,
  CARD_TYPE_CHECKER.THREE,
  CARD_TYPE_CHECKER.STRAIGHT,
  CARD_TYPE_CHECKER.PAIR,
  CARD_TYPE_CHECKER.FOUR,
  CARD_TYPE_CHECKER.SINGLE,
}

local function get_card_type(cards, last)
  local function group_card(cards)
    local card_set = {}
    table.sort(cards, function (a, b) 
        if a > b then
          return true
        end
      end)
    for _, v in ipairs(cards) do
      table.insert(card_set, ALL_CARDS[v])
    end
    
    --相等的权重即为一组
    local function group(cardSet)
      local g = {}
      local len = #cardSet
   
      local cursor = 0
      while cursor < len do
        cursor = cursor + 1
        local t = {}
        local prev = prev or cardSet[cursor][2]
        table.insert(t, cardSet[cursor])

        local step = 0
        for j = cursor + 1, len do 
          if prev == cardSet[j][2] then
            table.insert(t, cardSet[j])
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

    local groups = group(card_set)
    return groups
  end

  local card_num = #cards
  assert(#cards <= 18)

  local groups = group_card(cards)
  local card_groups = {}
  local card_type  
  for k, v in ipairs(CHECKER) do 
    print("card type check ", v.name)
    local ret, other = v.func(groups, card_num, card_groups, last)
    if ret then
      card_type = v.name
      if card_type == CARD_TYPE.Three then
        if other > 1 then
          card_type = CARD_TYPE.Plane 
        end
        groups = card_groups  --进行数据结构替换
      end

      if card_type == CARD_TYPE.Pair then
        if other > 1 then
          card_type = CARD_TYPE.Pairs 
        end
      end

      break
    end
  end

  return card_type, groups 
end

function M.compare(cards, prevNum, prevCardType, prevGroups, last)
  local function compare_group(ga, gb, cardType)
    if cardType ~= CARD_TYPE.Three and cardType ~= CARD_TYPE.Plane and cardType ~= CARD_TYPE.Four then
      assert(#ga == #gb)
      for i = 1, #ga do
        if ga[i][1][2] <= gb[i][1][2] then
          return false
        end
      end
      return true
    elseif cardType ~= CARD_TYPE.Three or cardType ~= CARD_TYPE.Plane then
      for i = 1, #ga do 
        if #ga[i] == 3 then
          if ga[i][1][2] <= gb[i][1][2] then
            return false
          end 
        else
          break
        end
      end
      return true
    else --四带一的情况
      if ga[1][1][2] < gb[1][1][2] then
        return false
      end
      return true
    end
  end

  if prevNum ~= nil then
    if #cards ~= 4 and #cards ~= prevNum then
      return "card_wrong_type"
    end

    local card_type, groups = get_card_type(cards)
    if card_type == prevCardType then
      if compare_group(groups, prevGroups, card_type) then
        return "ok", card_type, groups
      else
        return "card_not_bigger"
      end
    else
      if card_type == CARD_TYPE.Bomb then
        return "ok", card_type, groups
      else
        return "card_wrong_type"
      end
    end
  else
    local card_type, groups = get_card_type(cards, last)
    if not card_type then
      return "card_wrong_type"
    else
      return "ok", card_type, groups
    end
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

--按权重分组
local function groups(cardSet)
  local g = {}
  local len = #cardSet
   
  local cursor = 0
  while cursor < len do
    cursor = cursor + 1
    local t = {}
    local prev = prev or cardSet[cursor][2]
    table.insert(t, cardSet[cursor][3])

    local step = 0
    for j = cursor + 1, len do 
      if prev == cardSet[j][2] then
        table.insert(t, cardSet[j][3])
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

--转换成card id
local function getCard(cardSet)
  local card = {}
  for _,v in ipairs(cardSet) do 
    for i,c in ipairs(v) do
      table.insert(card, c[3])
    end
  end
  return card
end


--提示功能
function  M.searchCard(ACardType, ACardsNum, Agroups, BCards)  -- ACardType上家牌型  Agroups 上家牌分组  ACardsNum 上家出牌张数  BCards 手上的牌
  
  local searchCardNum = 3
  local cardSet = {}
  local BcardSet = getCardSet(BCards)
  local Bgroups = groups(BcardSet)
  local groups_set = {}
  for _,g in ipairs(Bgroups) do
     local type,group = get_card_type(g)
     table.insert(groups_set, {card_type = type, card_set = group})
  end
  local three_set = {}
  local pairs_set = {}

  for i,v in ipairs(groups_set) do
    if v.card_type == CARD_TYPE.Bomb then    --有炸弹处理
      if ACardType == CARD_TYPE.Bomb then
        if v.card_set[1][1][2] > Agroups[1][1][2] then
          table.insert(cardSet, {card_type = v.card_type, card_set = getCard(v.card_set), groups = v.cards })
        end 
      else
        table.insert(cardSet, {card_type = v.card_type, card_set = getCard(v.card_set), groups = v.cards })
      end
    end
    if v.card_type == nil then     --isThree无法判断单三张，另外计算三张
      for _,c in ipairs(v.card_set) do
        if #c == 3 then  table.insert(three_set, c) end
      end
    end
    if v.card_type == CARD_TYPE.Pair then     --对子
      table.insert(pairs_set, v.card_set[1])
    end
  end 
  if #BCards < ACardsNum and #cardSet <= 0 then
      return "card_not_bigger"
  end
  local function table_sort(table_set)
     table.sort(table_set, function (a, b) 
              if a[1][3] < b[1][3] then
                return true
              end
            end ) 
     return table_set
  end
  table.sort(groups_set, function (a, b) 
              if a.card_set[1][1][3] < b.card_set[1][1][3] then
                return true
              end
            end )
  table_sort(pairs_set)
  table_sort(three_set)

  if ACardType == CARD_TYPE.Plane then     --飞机
    local plane_num = tonumber(math.ceil(ACardsNum/5))

    local function deal_plane(cardSet, c_three, pairs_set, plane_num)  --处理飞机牌
      for k,c in ipairs(c_three) do
        if k + plane_num - 1 <= #c_three then
          local temp_c, temp_p= {}, {}
          local temp_tree = utils.simple_copy_obj(c_three)
          table.move(temp_tree, k, k + plane_num -1, 1, temp_c)
          temp_c = getCard(temp_c)
          if #pairs_set >= plane_num then
            local temp_paris = utils.simple_copy_obj(pairs_set)
            table.move(temp_paris, 1, plane_num, 1, temp_p)
            temp_p = getCard(temp_p)
          else
            local temp_paris = utils.simple_copy_obj(pairs_set)
            table.move(temp_paris, 1, #pairs_set, 1, temp_p)
            temp_p = getCard(temp_p)
            local index = #pairs_set
            local temp_tp = {}
            local temp_pp = utils.simple_copy_obj(three_set)
            for i,t in ipairs(temp_pp) do
              local index_three = true 
              for _,v in ipairs(temp_tree) do
                if t[1][2] == v[1][2] then
                   index_three = false
                end
              end
              if index_three then
                local temp_tt = {}
                table.move(t, 1, 2, 1, temp_tt)
                table.insert(temp_tp, temp_tt)
                index = index +1
                if index == plane_num then
                  break
                end
              end
            end
            temp_tp = getCard(temp_tp)
            table.move(temp_tp, 1, #temp_tp, #temp_p + 1, temp_p)
          end
          table.move(temp_p, 1, #temp_p, #temp_c + 1, temp_c)
          local index = true
          for _,v in ipairs(cardSet) do 
            if v.card_type == ACardType and temp_c == v.card_set then 
              index = false
              break
            end
          end
          if index then
            local ret, card_type, groups = M.compare(temp_c)
            if ret == "ok" and card_type == ACardType then
              table.insert(cardSet, {card_type = ACardType, card_set = temp_c, groups = groups})
              if #cardSet >= searchCardNum then return "ok", cardSet end
            end
          end
        end 
      end
    end 

    
    local prev = nil
    local c_three = {}
    local c_num = 0

    if plane_num <= #three_set and (plane_num <= #pairs_set or #pairs_set + (#three_set - plane_num) >= plane_num) then
      for _,t in ipairs(three_set) do
        if prev then
          if t[1][2] ~= prev[1][2] +1 then
            if c_num >= plane_num then
              deal_plane(cardSet, c_three, pairs_set, plane_num)
            end
            c_three = {}
            prev = t
            table.insert(c_three, t)
          else
            c_num = c_num +1
            table.insert(c_three, t)
            prev = t
          end
        elseif t[1][2] < Agroups[1][1][2] then   --小于飞机头张牌跳出
          break
        else
          prev = t
          c_num = c_num +1
          table.insert(c_three, t)
        end
      end
      if #c_three ~= 0 and #c_three >= plane_num then
        deal_plane(cardSet, c_three, pairs_set, plane_num)
      end
    end

  elseif ACardType == CARD_TYPE.Three then      --三带   （未有最后一手先手不带的处理）
    if #three_set >= 0 and (#pairs_set >= 0 or #three_set > 1)then
      for i,v in ipairs(three_set) do
        if v[1][2] > Agroups[1][1][2] then
          local temp_t = {}
          temp_t = getCard({v})
          local tmep_tt = utils.simple_copy_obj(temp_t)
          if #pairs_set > 0 then
            local temp_pair = utils.simple_copy_obj(pairs_set)
            for _,p in ipairs(temp_pair) do
              p = getCard({p})
              local three = utils.simple_copy_obj(tmep_tt)
              table.move(p, 1, 2, 4, three)
              local ret, card_type, groups = M.compare(three)
              if ret == "ok" and card_type == ACardType then
                table.insert(cardSet, {card_type = ACardType, card_set = three, groups = groups })
                if #cardSet >= searchCardNum then return "ok", cardSet end
              end
            end
          else
            local temp_three = utils.simple_copy_obj(three_set)
            for k,t in ipairs(temp_three) do
              if t[1][2] ~= v[1][2] then
                local temp_p = {}
                local tt = utils.simple_copy_obj(t)
                table.move(tt, 1, 2, 1, temp_p)
                temp_p = getCard({temp_p})
                local three = utils.simple_copy_obj(tmep_tt)
                table.move(temp_p, 1, 2, 4, three)
                local ret, card_type, groups = M.compare(three)
                if ret == "ok" and card_type == ACardType then
                  table.insert(cardSet, {card_type = ACardType, card_set = three, groups = groups })
                  if #cardSet >= searchCardNum then return "ok", cardSet end
                end
              end
            end  
          end
        end
      end
    end
  elseif ACardType == CARD_TYPE.Straight then    -- 链子

    if #groups_set >= ACardsNum then
      local temp = {}
      for i = 1, #groups_set do
        table.insert(temp, {groups_set[i].card_set[1][1]})
      end
      
      for k,t in ipairs(temp) do
         local temp_s, temp_str = {},{}
         local temp_t = utils.simple_copy_obj(temp)
         if k + ACardsNum - 1 <= #temp then
            table.move(temp_t, k, k + ACardsNum - 1, 1, temp_s)
            temp_str = utils.simple_copy_obj(temp_s)
            table.sort(temp_str, function (a, b) 
              if a[1][2] > b[1][2] then
                return true
              end
            end )
            local ok = isStraight(temp_str, ACardsNum)
            if ok then
              if temp_s[1][1][2] > Agroups[ACardsNum][1][2] then
                local ret, card_type, groups = M.compare(getCard(temp_s))
                if ret == "ok" and card_type == ACardType then
                  table.insert(cardSet, {card_type = ACardType, card_set = getCard(temp_s), groups = groups})
                  if #cardSet >= searchCardNum then return "ok", cardSet end
                end
              end
            end
         end
      end
    end

  elseif ACardType == CARD_TYPE.Pairs then     --连对

    local pairs_num = tonumber(math.ceil(ACardsNum/2))

    local function deal_pairs(cardSet, c_pairs, pairs_num)
      for k,c in ipairs(c_pairs) do
       if k + pairs_num -1 <= #c_pairs then
          local temp_c = {}
          local index = true
          local temp_paris = utils.simple_copy_obj(c_pairs)
          table.move(temp_paris, k, k + pairs_num - 1, 1, temp_c)
          for _,v in ipairs(cardSet) do 
            if v.card_type == ACardType then
              if temp_c[1][1][3] == v.card_set[1] then
                index = false
              end
            end
          end
          if index then
            local ret, card_type, groups = M.compare(getCard(temp_c))
            if ret == "ok" and card_type == ACardType then
             table.insert(cardSet, {card_type = ACardType, card_set = getCard(temp_c), groups = groups})
             if #cardSet >= searchCardNum then return "ok", cardSet end
            end
          end
       end 
      end
    end
 
    
    local prev = nil
    local c_pairs = {}
    local c_num = 0
    local new_pairs = {}

    for _,g in ipairs(groups_set) do
      if #g.card_set[1] >= 2 then
        local temp_paris = {}
        table.move(g.card_set[1], 1, 2, 1, temp_paris)
        table.insert(new_pairs, temp_paris)
      end
    end
    if pairs_num <= #new_pairs then
      for _,t in ipairs(new_pairs) do
        if prev then
          if t[1][2] ~= prev[1][2] +1 then
            if #c_pairs >= pairs_num then
              deal_pairs(cardSet, c_pairs, pairs_num)
            end
            c_pairs = {}
            prev = t
            table.insert(c_pairs, t)
          else
            prev = t
            c_num = c_num +1
            table.insert(c_pairs, t)
          end
        elseif t[1][2] < Agroups[1][1][2] then   --小于飞机头张牌跳出
          break
        else
          prev = t
          c_num = c_num +1
          table.insert(c_pairs, t)
        end
      end
   
      if #c_pairs ~= 0 and #c_pairs >= pairs_num then
        deal_pairs(cardSet, c_pairs, pairs_num)
      end
    end

  elseif ACardType == CARD_TYPE.Pair then
    local index =true
    if #pairs_set > 0 then
      for i,v in ipairs(pairs_set) do   --对子
        if v[1][2] > Agroups[1][1][2] then
          local temp, tempcards = {}, {}
          table.insert(tempcards, v)
          temp.card_type = ACardType
          temp.card_set = getCard(tempcards)
          temp.groups = tempcards
          table.insert(cardSet, temp)
          index = false
          if #cardSet >= searchCardNum then return "ok", cardSet end
        end
      end
    end
    if #three_set > 0 and index then
      for i,v in ipairs(three_set) do   --三张里抽大的对子
        if v[1][2] > Agroups[1][1][2]  then
          local temp, tempcards = {}, {}
          local temp_v = utils.simple_copy_obj(v)
          table.move(temp_v,1,2,1,temp)
          table.insert(tempcards, temp)
          table.insert(cardSet, {card_type = ACardType, card_set = getCard(tempcards), groups = tempcards})
          if #cardSet >= searchCardNum then return "ok", cardSet end
        end
      end
    end

  elseif ACardType == CARD_TYPE.Single then    --单张

    local index = true
    for i,v in pairs(groups_set) do
      if #v.card_set[1] == 1 then     --考虑单张
        if v.card_set[1][1][2] > Agroups[1][1][2] then
          table.insert(cardSet, {card_type = ACardType, card_set = getCard(v.card_set), groups = v.card_set })
          index = false
          if #cardSet >= searchCardNum then return "ok", cardSet end
        end
      end
    end
    if index then
      for i,v in pairs(groups_set) do
        if #v.card_set[1] > 1 then   --没单张时考虑非单张
          if v.card_set[1][1][2] > Agroups[1][1][2] then
            local card = getCard(v.card_set)
            table.insert(cardSet, {card_type = ACardType, card_set = { card[1] }, groups = { v.card_set[1][1] }})
            if #cardSet >= searchCardNum then return "ok", cardSet end
          end
        end
      end
    end
  elseif ACardType ==CARD_TYPE.Four then     --四带一

    for _,g in ipairs(groups_set) do
       if g.card_type == CARD_TYPE.Bomb then
          
          for i,a in ipairs(Agroups) do
            if #a == 4 then
              if g.card_set[1][1][3] > a[1][3] then
                 local four = getCard(g.card_set)
                 local single, three = true, true
                 for k,s in ipairs(groups_set) do
                    if #s.card_set[1] == 1 then single = false end
                 end
                 for k,s in ipairs(groups_set) do
                    local temp_f = {}
                    temp_f = utils.simple_copy_obj(four) 
                    if s.card_type == CARD_TYPE.Single then     --带单张
                      
                      local temp_s = getCard(s.card_set)
                      table.move(temp_s, 1, 1, #temp_f + 1, temp_f)
                    elseif s.card_type == CARD_TYPE.Pair and single then     --拆对子
                      local temp_s = getCard(s.card_set)
                      table.move(temp_s, 1, 1, #temp_f+1, temp_f)
                    elseif #three_set > 0 and single and three then     --拆三张
                      three = false
                      for c,t in ipairs(three_set) do
                        local temp_s = getCard({t})
                        table.move(temp_s, 1, 1, #temp_f + 1, temp_f)
                        break
                      end
                    end
                    if #temp_f ==5 then
                      local ret, card_type, groups = M.compare(temp_f)
                      if ret == "ok" and card_type == ACardType then
                        table.insert(cardSet, {card_type = ACardType, card_set = temp_f, groups = groups})
                        if #cardSet >= searchCardNum then return "ok", cardSet end
                      end
                    end
                  end
              end
            end
          end
       end
    end
  end

  if #cardSet ~= 0 then
    print("CardSet", inspect(cardSet))
    return "ok", cardSet
  else
    return "card_not_bigger"
  end
end

function M.test()
  --local cards = {1, 5, 9} -- straight
  --local cards = {1, 2, 3, 5, 6, 7, 9, 10, 13, 14} -- plane
  --local cards = {1, 2, 5, 6}
  -- local cards = {1}
  -- local card_type, groups = get_card_type(cards)

  local card1 = {1, 2, 3, 5, 6}   -- three cmp
  local card2 = {9, 10, 11, 7, 8}

  -- local card1 = {1, 5, 9}   -- seq cmp
  -- local card2 = {5, 9, 13}

  -- local card1 = {1, 2, 5, 6}   -- pairs cmp
  -- local card2 = {9, 10, 7, 8}

  -- local card1 = {1, 2, 3, 5, 6, 7, 25, 26, 13, 14}   -- plane cmp
  -- local card2 = {17,18,19, 21, 22, 23, 11, 12, 15, 16 }    -- 333 444  55 55 这种情况处理不了

  local ok , type1, groups1 = M.compare(card1)
  print("type1 ------------ ", type1)
  utils.var_dump(groups1)

  local ok, type2, groups2 = M.compare(card2, #card1, type1, groups1)
  print("----- ok -------- ", ok)
  print("type2 ------------ ", type2)
  utils.var_dump(groups2)
end

M.CARD_TYPE = CARD_TYPE

return M
