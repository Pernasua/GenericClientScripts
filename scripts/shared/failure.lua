local function raise(event, status, details)
  local value = details or {}
  value.status = status
  gc.log("error", event, value)
  error(status, 0)
end

return { raise = raise }
