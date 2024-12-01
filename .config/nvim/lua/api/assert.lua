---@module "api.types"
local types = require 'api.types'

---@alias api.assert.Type # The assertion type.
---| api.types.Type # the base type.
---| api.assert.Type[] # a list of types.
---| { [1]: 'list', [2]: api.assert.Type } # a list of values.
---| { ['*']: api.assert.Type } # a list validator.
---| { [string|number]: api.assert.Type } # a sub-table.

---@class (exact) api.assert.AssertEntry # An assertion entry.
---@field [1] any # the value to assert.
---@field [2] api.assert.Type # the type of the value.

---@alias api.assert.AssertSchema # An assertion schema.
---| { [string|number]: api.assert.AssertEntry } # The field to assert.

---@class (exact) api.assert.ValidateError # The error of a validation.
---@field field string|nil # the field that failed the validation.
---@field expected_type api.types.Type # the expected type.
---@field actual_type api.types.Type # the actual type.
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

        if type(entry) ~= 'table' then
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
        local field_value_type = types.get(field_value)

        if type(field_schema) == 'string' then --[[@cast field_schema string]]
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

        if type(field_schema) ~= 'table' then
            table.insert(errors, {
                field = field_name,
                expected_type = 'table',
                actual_type = type(field_schema),
                message = 'invalid schema entry',
            })

            goto continue
        end

        ---@cast field_schema table

        local list_item_schema = schema['*']
        if list_item_schema then
            if field_value_type ~= 'list' then
                table.insert(errors, {
                    field = field_name,
                    expected_type = 'list',
                    actual_type = field_value_type,
                    message = 'not a list',
                })

                goto continue
            end

            ---@type api.assert.AssertSchema
            local composite_schema = {}
            for i, v in ipairs(field_value) do
                composite_schema[i] = { v, list_item_schema }
            end

            vim.list_extend(errors, validate(field_name, composite_schema))

            goto continue
        end

        if vim.islist(field_schema) then
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

        if field_value_type ~= 'list' and field_value_type ~= 'table' then
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
