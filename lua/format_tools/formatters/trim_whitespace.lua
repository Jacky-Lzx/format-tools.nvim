return {
  transform = function(_, text)
    return (text:gsub("[ \t]+\n", "\n"):gsub("[ \t]+$", ""))
  end,
}
