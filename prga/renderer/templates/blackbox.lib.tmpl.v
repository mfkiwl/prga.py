// Automatically generated by PRGA's blackbox library generator
module {{ module.name }} (
    {%- set comma = joiner(",") %}
    {%- for port in itervalues(module.ports) %}{{ comma() }}
    {{ port.direction.case('input', 'output') }} wire [{{ port|length - 1}}:0] {{ port.name }}
    {%- endfor %}
    );
    {%- for param, default_value in iteritems(module.parameters|default({})) %}
    parameter {{ param }} = {{ default_value }};
    {%- endfor %}
endmodule

