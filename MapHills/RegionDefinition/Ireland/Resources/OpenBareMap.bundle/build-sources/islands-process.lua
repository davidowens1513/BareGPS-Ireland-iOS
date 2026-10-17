node_keys = { "name", "name:ga", "name:en", "official_name", "place" }
way_keys = { "name", "name:ga", "name:en", "official_name", "place", "type" }

local function add_names()
  local name = Find("name")
  if name ~= "" then Attribute("name", name) end
  local name_ga = Find("name:ga")
  if name_ga ~= "" then Attribute("name_ga", name_ga) end
  local name_en = Find("name:en")
  if name_en ~= "" then Attribute("name_en", name_en) end
  local official_name = Find("official_name")
  if official_name ~= "" then Attribute("official_name", official_name) end
end

local function add_island(is_area)
  local place = Find("place")
  if (place ~= "island" and place ~= "islet") or Find("name") == "" then return end
  if is_area then LayerAsCentroid("island_name") else Layer("island_name") end
  Attribute("class", place)
  add_names()
  if place == "island" then MinZoom(7) else MinZoom(11) end
end

function node_function()
  add_island(false)
end

function way_function()
  add_island(true)
end

function relation_scan_function()
  local place = Find("place")
  if (place == "island" or place == "islet") and Find("name") ~= "" then Accept() end
end

function relation_function()
  add_island(true)
end
