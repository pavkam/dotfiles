; System call highlight

(function_call
  name: ((dot_index_expression) @_mm
    (#any-of? @_mm "vim.fn.system" "vim.system" "vim.loop.spawn" "vim.uv.spawn"))
  arguments: (arguments
    ( string content:
      (string_content) @injection.content
      (#set! injection.language "bash"))))

(function_call
  name: ((dot_index_expression) @_mm
    (#any-of? @_mm "vim.json.decode"))
  arguments: (arguments
    ( string content:
      (string_content) @injection.content
      (#set! injection.language "json"))))


