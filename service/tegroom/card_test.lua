local M = {}
local card = {}

local first = { 52, 46, 43, 42, 35, 32, 30, 26, 25, 24, 21, 11, 10, 7, 6, 5, 14 }
--assert(#first==15, "first player card num must 12")

local second = {53, 49, 47, 44, 38, 34, 29, 28, 27, 22, 18, 16, 15, 12, 9, 8, 13}
--assert(#second==15, "second player card num must 12")

local three = {51, 48, 45, 41, 40, 39, 37, 36, 33, 23, 20, 19, 17, 4, 3, 2, 1}


local set = {}
for i=1, 54 do 
  set[i] = true
end

local function table_combine(src, dst)
  for _, v in ipairs(dst) do 
    table.insert(src, v)
  end
end

table_combine(card, first)
table_combine(card, second)
table_combine(card, three)

for _, v in ipairs(card) do
  set[v] = false
end

local third = {}
for i= 1, 54 do 
  if set[i] then
    table.insert(third, i)
  end
end
assert(#third==3, "third player card num must 24")

table_combine(card, third)

M.card = card
M.test = false

return M

