return function(api)
  local scope = { current = nil, entries = {} }
  api.intent = function(name, fn)
    local previous = scope.current
    if not previous then
      scope.current = name
      scope.entries[#scope.entries + 1] = name
    end
    local result = table.pack(pcall(fn))
    scope.current = previous
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
  end
  return scope
end
