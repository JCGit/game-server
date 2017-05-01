local M = {}
local card = {}

local first = {1, 2, 3, 4, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49, 53}
assert(#first==15, "first player card num must 12")

local second = {5,  6, 7, 8, 20, 22, 23, 24, 14, 26, 27, 28, 48, 46, 54}
assert(#second==15, "second player card num must 12")

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

for _, v in ipairs(card) do
  set[v] = false
end

local third = {}
for i= 1, 54 do 
  if set[i] then
    table.insert(third, i)
  end
end
assert(#third==24, "third player card num must 24")

table_combine(card, third)

M.card = card
M.test = false

return M

