local M = {}

--   显示     权重  序号
M.ALL_CARDS = {
  { '方块3'  , 3  , 1} ,
  { '梅花3'  , 3  , 2} ,
  { '红桃3'  , 3  , 3} ,
  { '黑桃3'  , 3  , 4} ,
  { '方块4'  , 4  , 5} ,
  { '梅花4'  , 4  , 6} ,
  { '红桃4'  , 4  , 7} ,
  { '黑桃4'  , 4  , 8} ,
  { '方块5'  , 5  , 9} ,
  { '梅花5'  , 5  , 10} ,
  { '红桃5'  , 5  , 11} ,
  { '黑桃5'  , 5  , 12} ,
  { '方块6'  , 6  , 13} ,
  { '梅花6'  , 6  , 14} ,
  { '红桃6'  , 6  , 15} ,
  { '黑桃6'  , 6  , 16} ,
  { '方块7'  , 7  , 17} ,
  { '梅花7'  , 7  , 18} ,
  { '红桃7'  , 7  , 19} ,
  { '黑桃7'  , 7  , 20} ,
  { '方块8'  , 8  , 21} ,
  { '梅花8'  , 8  , 22} ,
  { '红桃8'  , 8  , 23} ,
  { '黑桃8'  , 8  , 24} ,
  { '方块9'  , 9  , 25} ,
  { '梅花9'  , 9  , 26} ,
  { '红桃9'  , 9  , 27} ,
  { '黑桃9'  , 9  , 28} ,
  { '方块10' , 10 , 29} ,
  { '梅花10' , 10 , 30} ,
  { '红桃10' , 10 , 31} ,
  { '黑桃10' , 10 , 32} ,
  { '方块J'  , 11 , 33} ,
  { '梅花J'  , 11 , 34} ,
  { '红桃J'  , 11 , 35} ,
  { '黑桃J'  , 11 , 36} ,
  { '方块Q'  , 12 , 37} ,
  { '梅花Q'  , 12 , 38} ,
  { '红桃Q'  , 12 , 39} ,
  { '黑桃Q'  , 12 , 40} ,
  { '方块K'  , 13 , 41} ,
  { '梅花K'  , 13 , 42} ,
  { '红桃K'  , 13 , 43} ,
  { '黑桃K'  , 13 , 44} ,  
  { '方块A'  , 14 , 45} ,
  { '梅花A'  , 14 , 46} ,
  { '红桃A'  , 14 , 47} ,
  { '黑桃A'  , 14 , 48} ,
  { '方块2'  , 15 , 49} ,
  { '梅花2'  , 15 , 50} ,
  { '红桃2'  , 15 , 51} ,
  { '黑桃2'  , 15 , 52} ,
  { '小王'  ,  16 , 53} ,
  { '大王'  ,  18 , 54} ,  --不成顺子， 隔一个值
}

M.CARD_MOUNT = #M.ALL_CARDS

M.CARD_TYPES = {
  ["Single"]   = "SINGLE",    -- 单张
  ["Pair"]     = "PAIR",      -- 对子
  ["Pairs"]    = "PAIRS",     -- 连对
  ["Triple"]   = "TRIPLE",    -- 三带
  ["Boomb"]    = "BOOMB",     -- 炸弹
  ["Sright"]   = "STRIGHT",   --顺子
  ["FourD"]    = "FourD",     --四带
  ["Plane"]    = "PLANE",     --飞机
}

return M
