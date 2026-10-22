-- Embed a source file as a syntax-highlighted code block.
--
--   {{< codefile ../R/01_events.R r >}}
--
-- The path is resolved relative to the document, which is Quarto's working
-- directory while rendering. A second attempt is made relative to the project
-- root so the shortcode also works from top-level pages.
return {
  ["codefile"] = function(args, kwargs, meta)
    local path = pandoc.utils.stringify(args[1])
    local lang = pandoc.utils.stringify(args[2] or "text")
    local f, err = io.open(path, "r")
    if not f then
      f, err = io.open("../../" .. path, "r")
    end
    if not f then
      error("codefile: cannot open " .. path .. " (" .. tostring(err) .. ")")
    end
    local content = f:read("*a")
    f:close()
    return pandoc.Blocks({ pandoc.CodeBlock(content, pandoc.Attr("", { lang })) })
  end
}
