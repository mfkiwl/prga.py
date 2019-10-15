# -*- encoding: ascii -*-
# Python 2 and 3 compatible
from __future__ import division, absolute_import, print_function
from prga.compatible import *

from prga.arch.common import Position
from prga.algorithm.util.hierarchy import (hierarchical_instance, hierarchical_net, hierarchical_position,
        hierarchical_source)
from prga.flow.util import iter_all_tiles
from prga.util import uno

from itertools import chain, count, product

__all__ = ['vpr_arch_primitive', 'vpr_arch_instance', 'vpr_arch_block', 'vpr_arch_layout',
        'vpr_arch_segment', 'vpr_arch_default_switch', 'vpr_arch_xml']

# ----------------------------------------------------------------------------
# -- Primitive Model to VPR Architecture Description -------------------------
# ----------------------------------------------------------------------------
def vpr_arch_primitive(xml, primitive):
    with xml.element('model', {'name': primitive.name}):
        with xml.element('input_ports'):
            for iname, input_ in iteritems(primitive.ports):
                if not input_.direction.is_input:
                    continue
                attrs = {'name': iname}
                combinational_sink_ports = ' '.join(iter(oname for oname, output in iteritems(primitive.ports)
                    if output.direction.is_output and iname in output.combinational_sources))
                if combinational_sink_ports:
                    attrs['combinational_sink_ports'] = combinational_sink_ports
                if input_.is_clock:
                    attrs['is_clock'] = '1'
                elif input_.clock:
                    attrs['clock'] = input_.clock
                xml.element_leaf('port', attrs)
        with xml.element('output_ports'):
            for oname, output in iteritems(primitive.ports):
                if not output.direction.is_output:
                    continue
                attrs = {'name': oname}
                if output.is_clock:
                    attrs['is_clock'] = '1'
                elif output.clock:
                    attrs['clock'] = output.clock
                xml.element_leaf('port', attrs)

# ----------------------------------------------------------------------------
# -- Block to VPR Architecture Description -----------------------------------
# ----------------------------------------------------------------------------
def _bit2vpr(bit, parent = None):
    if bit.net_type.is_port:
        return '{}.{}[{}]'.format(parent or bit.parent.name, bit.bus.name, bit.index)
    else:
        return '{}.{}[{}]'.format(bit.parent.name, bit.bus.name, bit.index)

def _vpr_arch_interconnect(xml, sources, sink, module, parent = None):
    """Emit contents of an interconnect tag."""
    for source in sources:
        # fake timing
        xml.element_leaf('delay_constant', {
            'max': '1e-11',
            'in_port': _bit2vpr(source, parent),
            'out_port': _bit2vpr(sink, parent),
            })
        # pack pattern
        if (source, sink) in module.pack_patterns:
            xml.element_leaf('pack_pattern', {
                'name': 'pack_{}_{}_{}'.format(sink.parent.name, sink.bus.name, sink.index),
                'in_port': _bit2vpr(source, parent),
                'out_port': _bit2vpr(sink, parent),
                })
    with xml.element('metadata'):
        xml.element_leaf('meta', {'name': 'fasm_mux'}, '\n'.join(
            '{} : {}.{}[{}]-switchinput'.format(_bit2vpr(source, parent),
                source.parent.name, source.bus.name, source.index)
            for source in sources))

def _vpr_arch_clusterlike(xml, module, instance = None, parent = None):
    """Emit ``"pb_type"`` content for cluster-like modules."""
    parent = uno(parent, None if instance is None else instance.name)
    # 1. emit sub-instances
    lut_instances = {}
    for inst in itervalues(module.instances):
        vpr_arch_instance(xml, inst)
        if inst.module_class.is_primitive and inst.model.primitive_class.is_lut:
            lut_instances[inst.name] = len(inst.all_pins['in'])
    # 2. emit interconnect
    with xml.element('interconnect'):
        for pin in chain(iter(port for port in itervalues(module.ports) if port.direction.is_output),
                iter(pin for inst in itervalues(module.instances)
                    for pin in itervalues(inst.pins) if pin.direction.is_input)):
            for sink in pin:
                sources = tuple(src for src in sink.user_sources if not src.net_type.is_const)
                if len(sources) == 0:
                    continue
                elif len(sources) == 1:
                    with xml.element('direct', {
                        'name': 'direct_{}_{}_{}'.format(sink.parent.name, sink.bus.name, sink.index),
                        'input': _bit2vpr(sources[0], parent),
                        'output': _bit2vpr(sink, parent),
                        }):
                        _vpr_arch_interconnect(xml, sources, sink, module, parent)
                else:
                    with xml.element('mux', {
                        'name': 'mux_{}_{}_{}'.format(sink.parent.name, sink.bus.name, sink.index),
                        'input': ' '.join(map(lambda x: _bit2vpr(x, parent), sources)),
                        'output': _bit2vpr(sink, parent),
                        }):
                        _vpr_arch_interconnect(xml, sources, sink, module, parent)
    # 3. fasm metadata
    if instance is None and len(lut_instances) == 0:
        return
    with xml.element('metadata'):
        if instance is not None:
            xml.element_leaf('meta', {'name': 'fasm_prefix'}, instance.name)
        # xml.element_leaf('meta', {'name': 'fasm_features'}, module.name)
        if len(lut_instances) > 1:
            xml.element_leaf('meta', {'name': 'fasm_type'}, 'SPLIT_LUT')
            xml.element_leaf('meta', {'name': 'fasm_lut'}, '\n'.join(
                '{}-lutcontent[{}:0] = {}'.format(name, 2 ** width - 1, name)
                for name, width in iteritems(lut_instances)))
        elif len(lut_instances) == 1:
            name, width = next(iteritems(lut_instances))
            xml.element_leaf('meta', {'name': 'fasm_type'}, 'LUT')
            xml.element_leaf('meta', {'name': 'fasm_lut'},
                    '{}-lutcontent[{}:0]'.format(name, 2 ** width - 1))

def _vpr_arch_cluster_instance(xml, instance):
    """Emit ``"pb_type"`` for cluster instance."""
    cluster = instance.model
    with xml.element('pb_type', {'name': instance.name, 'num_pb': '1'}):
        # 1. emit ports
        for port in itervalues(cluster.ports):
            xml.element_leaf(
                    'clock' if port.is_clock else port.direction.case('input', 'output'),
                    {'name': port.name, 'num_pins': port.width})
        # 2. do the rest of the cluster
        _vpr_arch_clusterlike(xml, cluster, instance)

def _vpr_arch_primitive(xml, instance):
    primitive = instance.model
    parent = instance.name
    # 1. emit ports
    for port in itervalues(primitive.ports):
        attrs = {'name': port.name, 'num_pins': port.width}
        if port.port_class is not None:
            attrs['port_class'] = port.port_class.name
        xml.element_leaf(
                'clock' if port.is_clock else port.direction.case('input', 'output'),
                attrs)
    # 2. fake timing
    for port in itervalues(primitive.ports):
        if port.is_clock:
            continue
        if port.clock is not None:
            if port.direction.is_input:
                for bit in port:
                    xml.element_leaf('T_setup', {
                        'port': _bit2vpr(bit, parent),
                        'value': '1e-11',
                        'clock': port.clock,
                        })
            else:
                for bit in port:
                    xml.element_leaf('T_clock_to_Q', {
                        'port': _bit2vpr(bit, parent),
                        'max': '1e-11',
                        'clock': port.clock,
                        })
        if port.direction.is_output:
            for source in port.combinational_sources:
                for src, sink in product(iter(primitive.ports[source]), iter(port)):
                    xml.element_leaf('delay_constant', {
                        'max': '1e-11',
                        'in_port': _bit2vpr(src, parent),
                        'out_port': _bit2vpr(sink, parent),
                        })
    # 3. FASM metadata
    # with xml.element('metadata'):
    #     xml.element_leaf('meta', {'name': 'fasm_features'}, primitive.name)

def _vpr_arch_primitive_instance(xml, instance):
    """Emit ``"pb_type"`` for primitive instance."""
    primitive = instance.model
    if primitive.primitive_class.is_iopad:
        with xml.element('pb_type', {'name': instance.name, 'num_pb': '1'}):
            xml.element_leaf('input', {'name': 'outpad', 'num_pins': '1'})
            xml.element_leaf('output', {'name': 'inpad', 'num_pins': '1'})
            with xml.element('mode', {'name': 'inpad'}):
                with xml.element('pb_type', {'name': 'inpad', 'blif_model': '.input', 'num_pb': '1'}):
                    xml.element_leaf('output', {'name': 'inpad', 'num_pins': '1'})
                with xml.element('interconnect'):
                    with xml.element('direct', {'name': 'inpad',
                        'input': 'inpad.inpad', 'output': '{}.inpad'.format(instance.name)}):
                        xml.element_leaf('delay_constant', {'max': '1e-11',
                            'in_port': 'inpad.inpad', 'out_port': '{}.inpad'.format(instance.name)})
                with xml.element('metadata'):
                    xml.element_leaf('meta', {'name': 'fasm_features'}, 'inpad-modeselect')
            with xml.element('mode', {'name': 'outpad'}):
                with xml.element('pb_type', {'name': 'outpad', 'blif_model': '.output', 'num_pb': '1'}):
                    xml.element_leaf('input', {'name': 'outpad', 'num_pins': '1'})
                with xml.element('interconnect'):
                    with xml.element('direct', {'name': 'outpad',
                        'output': 'outpad.outpad', 'input': '{}.outpad'.format(instance.name)}):
                        xml.element_leaf('delay_constant', {'max': '1e-11',
                            'out_port': 'outpad.outpad', 'in_port': '{}.outpad'.format(instance.name)})
                with xml.element('metadata'):
                    xml.element_leaf('meta', {'name': 'fasm_features'}, 'outpad-modeselect')
            with xml.element('metadata'):
                xml.element_leaf('meta', {'name': 'fasm_prefix'}, instance.name)
                # xml.element_leaf('meta', {'name': 'fasm_features'}, instance.model.name)
        return
    elif primitive.primitive_class.is_multimode:
        with xml.element('pb_type', {'name': instance.name, 'num_pb': '1'}):
            # 1. emit ports
            for port in itervalues(primitive.ports):
                xml.element_leaf(
                        'clock' if port.is_clock else port.direction.case('input', 'output'),
                        {'name': port.name, 'num_pins': port.width})
            # 2. emit modes
            for mode in itervalues(primitive.modes):
                with xml.element('mode', {'name': mode.name}):
                    _vpr_arch_clusterlike(xml, mode, instance)
            with xml.element('metadata'):
                xml.element_leaf('meta', {'name': 'fasm_prefix'}, instance.name)
                # xml.element_leaf('meta', {'name': 'fasm_features'}, instance.model.name)
        return
    attrs = {'name': instance.name, 'num_pb': '1'}
    if primitive.primitive_class.is_lut:
        attrs.update({"blif_model": ".names", "class": "lut"})
    elif primitive.primitive_class.is_flipflop:
        attrs.update({"blif_model": ".latch", "class": "flipflop"})
    elif primitive.primitive_class.is_inpad:
        attrs.update({"blif_model": ".input"})
    elif primitive.primitive_class.is_outpad:
        attrs.update({"blif_model": ".output"})
    elif primitive.primitive_class.is_memory:
        attrs.update({"blif_model": ".subckt " + primitive.name, "class": "memory"})
    elif primitive.primitive_class.is_custom:
        attrs.update({"blif_model": ".subckt " + primitive.name})
    with xml.element('pb_type', attrs):
        _vpr_arch_primitive(xml, instance)

def vpr_arch_instance(xml, instance):
    """Convert an instance in a block into VPR architecture description.
    
    Args:
        xml (`XMLGenerator`):
        instance (`AbstractInstance`):
    """
    if instance.module_class.is_cluster:      # cluster
        _vpr_arch_cluster_instance(xml, instance)
    elif instance.module_class.is_primitive:  # primitive
        _vpr_arch_primitive_instance(xml, instance)

def vpr_arch_block(xml, tile):
    """Convert the block used in ``tile`` into VPR architecture description.
    
    Args:
        xml (`XMLGenerator`):
        tile (`Tile`):
    """
    with xml.element('pb_type', {
        'name': tile.name,
        'capacity': tile.capacity,
        'width': tile.width,
        'height': tile.height,
        }):
        # 1. emit ports
        for port in itervalues(tile.block.ports):
            attrs = {'name': port.name, 'num_pins': port.width}
            if port.net_class.is_global and not port.is_clock:
                attrs['is_non_clock_global'] = "true"
            xml.element_leaf(
                    'clock' if port.is_clock else port.direction.case('input', 'output'),
                    attrs)
        # 2. do the rest of the cluster
        _vpr_arch_clusterlike(xml, tile.block, parent = tile.name)
        # 4. pin locations
        with xml.element('pinlocations', {'pattern': 'custom'}):
            if tile.block.module_class.is_io_block:
                xml.element_leaf('loc', {'side': tile.orientation.case('bottom', 'left', 'top', 'right')},
                        ' '.join('{}.{}'.format(tile.name, port) for port in tile.block.ports))
            else:
                for y in range(tile.height):
                    # left
                    xml.element_leaf('loc', {'side': 'left', 'xoffset': '0', 'yoffset': y},
                        ' '.join('{}.{}'.format(tile.name, name) for name, port in iteritems(tile.block.ports)
                            if port.position == (0, y) and port.orientation.is_west))
                    # right
                    xml.element_leaf('loc', {'side': 'right', 'xoffset': tile.width - 1, 'yoffset': y},
                        ' '.join('{}.{}'.format(tile.name, name) for name, port in iteritems(tile.block.ports)
                            if port.position == (tile.width - 1, y) and port.orientation.is_east))
                for x in range(tile.width):
                    # bottom
                    xml.element_leaf('loc', {'side': 'bottom', 'xoffset': x, 'yoffset': '0'},
                        ' '.join('{}.{}'.format(tile.name, name) for name, port in iteritems(tile.block.ports)
                            if port.position == (x, 0) and port.orientation.is_south))
                    # top
                    xml.element_leaf('loc', {'side': 'top', 'xoffset': x, 'yoffset': tile.height - 1},
                        ' '.join('{}.{}'.format(tile.name, name) for name, port in iteritems(tile.block.ports)
                            if port.position == (x, tile.height - 1) and port.orientation.is_north))

# ----------------------------------------------------------------------------
# -- Layout to VPR Architecture Description ----------------------------------
# ----------------------------------------------------------------------------
def _vpr_arch_array(xml, array, hierarchy = None):
    """Convert an array to 'single' elements.

    Args:
        xml (`XMLGenerator`):
        array (`Array`):
        hierarchy (:obj:`Sequence` [`AbstractInstance` ]):
    """
    position = hierarchical_position(hierarchy) if hierarchy is not None else Position(0, 0)
    for pos, instance in iteritems(array.element_instances):
        pos += position
        if instance.module_class.is_tile:
            fasm_prefix = '.'.join(inst.name for inst in hierarchical_instance(instance, hierarchy))
            with xml.element('single', {
                'type': instance.model.name,
                'priority': '1',
                'x': pos.x,
                'y': pos.y,
                }):
                with xml.element('metadata'):
                    xml.element_leaf('meta', {'name': 'fasm_prefix'},
                            '\n'.join('{}[{}]'.format(fasm_prefix, idx) for idx in instance.model.block_instances))
        else:
            _vpr_arch_array(xml, instance.model, hierarchical_instance(instance, hierarchy))

def vpr_arch_layout(xml, array):
    """Convert a top-level array to VPR architecture description.

    Args:
        xml (`XMLGenerator`):
        array (`Array`):
    """
    with xml.element('layout'):
        with xml.element('fixed_layout', {'name': array.name, 'width': array.width, 'height': array.height}):
            _vpr_arch_array(xml, array)

# ----------------------------------------------------------------------------
# -- Segment to VPR Architecture Description ---------------------------------
# ----------------------------------------------------------------------------
def vpr_arch_segment(xml, segment):
    """Convert a segment to VPR architecture description.

    Args:
        xml (`XMLGenerator`):
        segment (`Segment`):
    """
    with xml.element('segment', {
        'name': segment.name,
        'freq': '1.0',
        'length': segment.length,
        'type': 'unidir',
        'Rmetal': '0.0',
        'Cmetal': '0.0',
        }):
        # fake switch
        xml.element_leaf('mux', {'name': 'default'})
        xml.element_leaf('sb', {'type': 'pattern'}, ' '.join(iter('1' for i in range(segment.length + 1))))
        xml.element_leaf('cb', {'type': 'pattern'}, ' '.join(iter('1' for i in range(segment.length))))

def vpr_arch_default_switch(xml):
    """Generate a default switch tag to VPR architecture description.

    Args:
        xml (`XMLGenerator`):
    """
    xml.element_leaf('switch', {
        'type': 'mux',
        'name': 'default',
        'R': '0.0',
        'Cin': '0.0',
        'Cout': '0.0',
        'Tdel': '1e-11',
        'mux_trans_size': '0.0',
        'buf_size': '0.0',
        })

# ----------------------------------------------------------------------------
# -- Generate Full VPR Architecture XML --------------------------------------
# ----------------------------------------------------------------------------
def vpr_arch_xml(xml, context):
    """Generate the full VPR architecture XML for ``context``.

    Args:
        xml (`XMLGenerator`):
        context (`BaseArchitectureContext`):
    """
    with xml.element('architecture'):
        # models
        with xml.element('models'):
            for primitive in itervalues(context.primitives):
                if primitive.primitive_class.is_custom or primitive.primitive_class.is_memory:
                    vpr_arch_primitive(xml, primitive)
        # # tiles
        # with xml.element('tiles'):
        #     for tile in iter_all_tiles(context):
        #         vpr_arch_tile(xml, tile)
        # layout
        vpr_arch_layout(xml, context.top)
        # device: faked
        with xml.element('device'):
            xml.element_leaf('sizing', {'R_minW_nmos': '0.0', 'R_minW_pmos': '0.0'})
            xml.element_leaf('connection_block', {'input_switch_name': 'default'})
            xml.element_leaf('area', {'grid_logic_tile_area': '0.0'})
            xml.element_leaf('switch_block', {'type': 'wilton', 'fs': '3'})
            xml.element_leaf('default_fc',
                    {'in_type': 'frac', 'in_val': '1.0', 'out_type': 'frac', 'out_val': '1.0'})
            with xml.element('chan_width_distr'):
                xml.element_leaf('x', {'distr': 'uniform', 'peak': '1.0'})
                xml.element_leaf('y', {'distr': 'uniform', 'peak': '1.0'})
        # switchlist
        with xml.element('switchlist'):
            vpr_arch_default_switch(xml)
        # segmentlist
        with xml.element('segmentlist'):
            for segment in itervalues(context.segments):
                vpr_arch_segment(xml, segment)
        # complexblocklist
        with xml.element('complexblocklist'):
            for tile in iter_all_tiles(context):
                vpr_arch_block(xml, tile)
