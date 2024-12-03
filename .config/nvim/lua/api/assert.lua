---@alias api.assert.Type # The assertion type.
---| extended_type # the base type.
---| api.assert.Type[] # a list of types.
---| { [1]: 'list', ['*']: api.assert.Type|nil, ['<']: integer|nil, ['>']: integer|nil  } # a list of values.
---| { [1]: 'number'|'integer', ['<']: integer|nil, ['>']: integer|nil } # a number.
---| { [1]: 'number'|'integer'|'string', ['*']: string|nil, ['<']: integer|nil, ['>']: integer|nil } # a string.
---| { [string|number]: api.assert.Type } # a sub-table.

---@class (exact) api.assert.AssertEntry # An assertion entry.
---@field [1] any # the value to assert.
---@field [2] api.assert.Type # the type of the value.

---@alias api.assert.AssertSchema # An assertion schema.
---| { [string|number]: api.assert.AssertEntry } # The field to assert.

---@class (exact) api.assert.ValidateError # The error of a validation.
---@field field string|nil # the field that failed the validation.
---@field expected_type extended_type # the expected type.
---@field actual_type extended_type # the actual type.
---@field message string # the message to display.

-- Validates a given schema.
---@param parent_field_name string|nil # the key to assert.
---@param schema api.assert.AssertSchema # the schema to validate.
---@return api.assert.ValidateError[] # the result of the validation.
local function validate(parent_field_name, schema)
    if type(schema) ~= 'table' then
        return {
            {
                field = parent_field_name,
                expected_type = 'table',
                actual_type = type(schema),
                message = 'invalid schema',
            },
        }
    end

    ---@type api.assert.ValidateError[]
    local errors = {}

    for key, entry in pairs(schema) do
        local field_name = parent_field_name and string.format('%s.%s', parent_field_name, tostring(key))
            or tostring(key)

        if extended_type(entry) ~= 'table' then
            table.insert(errors, {
                field = field_name,
                expected_type = 'table',
                actual_type = type(entry),
                message = 'invalid schema entry',
            })

            goto continue
        end

        local field_value = entry[1]
        local field_schema = entry[2]
        local field_value_raw_type, field_value_type = extended_type(field_value)
        local field_schema_raw_type, field_schema_type = extended_type(field_schema)

        if field_schema_raw_type == 'string' then --[[@cast field_schema string]]
            if field_value_type ~= field_schema then
                table.insert(errors, {
                    field = field_name,
                    expected_type = field_schema,
                    actual_type = field_value_type,
                    message = 'invalid type',
                })
            end

            goto continue
        end

        if field_schema_raw_type ~= 'table' then
            table.insert(errors, {
                field = field_name,
                expected_type = 'table',
                actual_type = field_schema_raw_type,
                message = 'invalid schema entry',
            })

            goto continue
        end

        ---@cast field_schema table
        if field_schema_type == 'table' and extended_type(field_schema[1]) == 'string' then
            local possible_type = field_schema[1] --[[@as extended_type]]
            local lt = extended_type(field_schema['<']) == 'number' and field_schema['<'] or nil
            local gt = extended_type(field_schema['>']) == 'number' and field_schema['>'] or nil

            if possible_type == 'list' then
                if field_value_type ~= possible_type then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = possible_type,
                        actual_type = field_value_type,
                        message = 'not a list',
                    })

                    goto continue
                end

                if lt and #field_value > lt then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('list is too long (expected at most `%d`)', lt),
                    })

                    goto continue
                end

                if gt and #field_value < gt then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('list is too short (expected at least `%d`)', gt),
                    })

                    goto continue
                end

                local list_item_schema = field_schema['*']

                if list_item_schema ~= nil then
                    ---@type api.assert.AssertSchema
                    local composite_schema = {}
                    for i, v in ipairs(field_value) do
                        composite_schema[i] = { v, list_item_schema }
                    end

                    vim.list_extend(errors, validate(field_name, composite_schema))
                end

                goto continue
            end

            if possible_type == 'integer' or possible_type == 'number' then
                if field_value_type ~= possible_type then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = possible_type,
                        actual_type = field_value_type,
                        message = 'invalid type',
                    })

                    goto continue
                end

                if lt and field_value > lt then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('value is too large (expected at most `%d`)', lt),
                    })

                    goto continue
                end

                if gt and field_value < gt then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('value is too small (expected at least `%d`)', gt),
                    })

                    goto continue
                end

                goto continue
            end

            if possible_type == 'string' then
                if field_value_type ~= possible_type then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = possible_type,
                        actual_type = field_value_type,
                        message = 'invalid type',
                    })

                    goto continue
                end

                if lt and #field_value > lt then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('string is too long (expected at most `%d`)', lt),
                    })

                    goto continue
                end

                if gt and #field_value < gt then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('string is too short (expected at least `%d`)', gt),
                    })

                    goto continue
                end

                local string_match = extended_type(field_schema['*']) == 'string' and field_schema['*'] or nil
                if string_match ~= nil and not field_value:match(string_match) then
                    table.insert(errors, {
                        field = field_name,
                        expected_type = field_value_type,
                        actual_type = field_value_type,
                        message = string.format('string does not match pattern `%s`', string_match),
                    })

                    goto continue
                end

                goto continue
            end
        end

        if field_schema_type == 'list' then
            local all_inner_errors = {}
            for _, candidate_schema in ipairs(field_schema) do
                local inner_errors = validate(field_name, { field_value, candidate_schema })

                if #inner_errors == 0 then
                    all_inner_errors = {}
                    break
                else
                    table.insert(all_inner_errors, inner_errors)
                end
            end

            vim.list_extend(errors, all_inner_errors)

            goto continue
        end

        if field_value_raw_type ~= 'table' then
            table.insert(errors, {
                field = field_name,
                expected_type = 'table | list',
                actual_type = field_value_type,
                message = 'invalid type',
            })

            goto continue
        end

        ---@type api.assert.AssertSchema
        local composite_schema = {}
        for k, v in pairs(composite_schema) do
            composite_schema[k] = { field_value[k], v }
        end

        vim.list_extend(errors, validate(field_name, composite_schema))

        ::continue::
    end

    return errors
end

-- Asserts the validity of a schema.
---@param input table<string, api.assert.AssertEntry> # the input to assert.
return function(input)
    local errors = validate(nil, input)

    if #errors > 0 then
        local formatted = 'assert failed:'
        for i, error in ipairs(errors) do
            if i > 1 then
                formatted = formatted .. '\n'
            end

            formatted = formatted
                .. string.format(
                    '  - [`%s`]: %s. expected type(s) `%s`, got `%s`.',
                    error.field,
                    error.message,
                    error.expected_type,
                    error.actual_type
                )
        end

        error(formatted)
    end
end
