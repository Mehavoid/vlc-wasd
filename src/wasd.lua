local function query_string(tbl, separator)
  local query = {}

  for key, value in pairs(tbl) do
    local index = #query + 1
    query[index] = string.format("%s=%s", key, value)
  end

  return table.concat(query, separator)
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

  return parse_json(chunks)
end


local LOG = "WASD: "


WASD = {
  api_call = function(path)
    local cors = "https://corsbypasser.herokuapp.com/"

    local data, _, err = get_json(cors.."https://wasd.tv/api/"..path)

    if err then
      vlc.msg.err(LOG..err)
      return nil
    end

    return data.result
  end,

  id = function(channel)
    local res = WASD.api_call("channels/nicknames/"..channel)

    if res then
      return res.channel_id
    end

    return 0
  end,

  streams = function(id)
    local params = {
      media_container_status = "RUNNING",
      media_container_type = "SINGLE,COOP",
      limit = 1,
      offset = 0,
      channel_id = id,
    }

    local query = query_string(params, "&")

    local containers = WASD.api_call("media-containers?"..query)

    if #containers == 0 then
      return {}
    end

    local container = containers[1].media_container_streams[1]

    return {
      artist = container.stream_channel.channel_name,
      description = container.stream_description,
      name = container.stream_name,
      path = container.stream_media[1].media_meta.media_url,
    }
  end,
}


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

  local id = tonumber(channel) or WASD.id(channel)

  if id == 0 then
    return { }
  end

  return { WASD.streams(id) }

end
