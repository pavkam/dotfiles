-- Shell commands extension: :Run command for async shell execution.

local Extension = require 'ide.Extension'

local ShellCommands = Class('ShellCommands', Extension)

function ShellCommands:init()
    Extension.init(self, 'ShellCommands')
end

function ShellCommands:on_register(ctx)
    ctx:command('Run', function(args)
        local parts = vim.split(args.args, '%s+')
        if #parts == 0 or parts[1] == '' then
            IDE.ui:error('No command specified')
            return
        end

        local cmd_line_desc = args.args
        local cmd = table.remove(parts, 1)
        local Buffer = require 'ide.Buffer'
        local input_lines = args.range > 0 and Buffer.current():lines(args.line1 - 1, args.line2) or nil

        IDE.shell:run(cmd, parts, { stdin = input_lines and table.concat(input_lines, '\n') or nil },
            function(result)
                local output = vim.split(vim.trim(result.stdout), '\n')
                if result.code ~= 0 then
                    IDE.ui:error(string.format('Command "%s" failed (exit %d)', cmd_line_desc, result.code))
                    return
                end

                local function esc(s) return s:gsub('`', '\\`') end

                if not args.bang then
                    if #output > 0 and output[1] ~= '' then
                        IDE.ui:info(string.format('Command "%s" finished:\n\n```sh\n%s\n```',
                            esc(cmd_line_desc), esc(table.concat(output, '\n'))))
                    else
                        IDE.ui:info(string.format('Command "%s" finished', esc(cmd_line_desc)))
                    end
                else
                    if args.range == 2 then
                        Buffer.current():set_lines(args.line1 - 1, args.line2, output)
                    elseif args.range == 1 then
                        Buffer.current():set_lines(0, -1, output)
                    else
                        IDE.ui:paste_lines(output)
                    end
                end
            end)
    end, { desc = 'Run shell command', bang = true, nargs = '+', range = true })
end

return ShellCommands
