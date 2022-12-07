local function contains(tab, key)
  return tab[key] ~= nil
end


local function is_empty(s)
  return s == nil or s == ""
end


local function query_string(tab, sep)
  local query = {}

  for key, val in pairs(tab) do
    local index = #query + 1
    query[index] = string.format("%s=%s", key, val)
  end

  return table.concat(query, sep)
end


local function parse_json(str)
  local json = require("dkjson")
  return json.decode(str)
end


local function get_json(url)
  local stream = vlc.stream(url)

  if not stream then
    return nil, nil, "Failed create vlc stream"
  end

  local chunks = ""

  while true do
    local chunk = stream:readline()

    if not chunk then
      break
    end

    chunks = chunks..chunk
  end

  if is_empty(chunks) then
    return nil, nil, "Got empty response from server"
  end

  return parse_json(chunks)
end


local PROXY = "https://0.wasd.workers.dev/?s="


local function api_call(path)
    local data, _, __ = get_json(PROXY.."https://wasd.tv/api/v2/"..path)
    if data then
      return data.result
    end
    return { }
end

local function streams(entity)
  local params = tonumber(entity) and
    { channel_id = entity } or
    { channel_name = entity }
  local query = query_string(params, "&")
  local res = api_call("broadcasts/public?"..query)
  local container = contains(res, "media_container") and res.media_container
  if not container then
    vlc.msg.err("WASD: Stream is currently offline.")
    return result
  end
  local streams = container.media_container_streams[1].stream_media
  return {
    artist = res.channel.channel_name,
    description = container.media_container_description,
    name = container.media_container_name,
    path = streams[1].media_meta.media_url,
  }
end


function probe()
  return
    (vlc.access == "http" or vlc.access == "https") and
    (
      vlc.path:match("^wasd%.tv/channel/%d+") or
      vlc.path:match("^wasd%.tv/embed/.+") or
      vlc.path:match("^wasd%.tv/.+")
    )
end


function parse()
  local channel =
    vlc.path:match("^wasd%.tv/channel/(%d+)") or
    vlc.path:match("^wasd%.tv/embed/([^/?#]+)") or
    vlc.path:match("^wasd%.tv/([^/?#]+)")

  return { streams(channel) }
end
