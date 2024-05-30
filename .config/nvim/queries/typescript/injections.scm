; This rule is used to detect SQL injection in a string fragment or template string.

(
    [
        (string_fragment)
    ] @injection.content
    (#match? @injection.content "(SELECT|INSERT|UPDATE|DELETE).+(FROM|INTO|VALUES|SET).*(WHERE|GROUP BY)?")
    (#set! injection.language "sql")
)

(
    [
        (template_string)
    ] @injection.content
    (#match? @injection.content "(SELECT|INSERT|UPDATE|DELETE).+(FROM|INTO|VALUES|SET).*(WHERE|GROUP BY)?")
    (#offset! @injection.content 0 1 0 -1)
    (#set! injection.language "sql")
)
