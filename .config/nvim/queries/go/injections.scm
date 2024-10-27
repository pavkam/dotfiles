; -- SQL injection detection; This rule is used to detect SQL injection in a string fragment or template string.

(
    [
        (raw_string_literal)
        (interpreted_string_literal)
    ] @injection.content
    (#match? @injection.content "(SELECT|INSERT|UPDATE|DELETE).+(FROM|INTO|VALUES|SET).*(WHERE|GROUP BY)?")
    (#set! injection.language "sql")
    (#set! injection.priority 150)
)
