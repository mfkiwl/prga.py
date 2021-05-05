{%- from 'macros/module.tmpl' import instantiation -%}
// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps
module {{ module.name }} (
    {%- set portcomma = joiner(", ") %}
    {%- for port in module.ports.values() %}
    {{ portcomma() }}{{ port.direction.case('input', 'output') }} wire [{{ port|length - 1}}:0] {{ port.name }}
    {%- endfor %}
    );
    {%- for param, attributes in (module.parameters|default({})).items() %}
    parameter {{ param }} = {{ attributes.default }};
    {%- endfor %}
    {% if module.is_cell %}
    // WARNING:
    //      {{ module }} is a cell module, therefore its contents are not generated
    {%- elif module.allow_multisource %}
    // WARNING:
    //      {{ module }} allows multi-source connections, therefore its contents
    //      are not generated
    {%- else %}
        {% for instance in module.instances.values() %}
            {%- for pin in instance.pins.values() %}
                {%- if pin.model.direction.is_output %}
    wire [{{ pin|length - 1 }}:0] _{{ instance.name }}__{{ pin.model.name }};
                {%- endif %}
            {%- endfor %}
        {%- endfor %}
        {% for instance in module.instances.values() %}
    {{ instantiation(instance) }} (
            {%- set pincomma = joiner(",") %}
            {%- for pin in instance.pins.values() %}
                {%- if pin.model.direction.is_input %}
        {{ pincomma() }}.{{ pin.model.name }}({{ source2verilog(pin)|indent(12) }})
                {%- else %}
        {{ pincomma() }}.{{ pin.model.name }}(_{{ instance.name }}__{{ pin.model.name }})
                {%- endif %}
            {%- endfor %}
        );
        {%- endfor %}
        {% for port in module.ports.values() %}
            {%- if port.direction.is_output %}
    assign {{ port.name }} = {{ source2verilog(port)|default("{}'bx".format(port|length), true)|indent(8) }};
            {%- endif %}
        {%- endfor %}
    {%- endif %}

endmodule

