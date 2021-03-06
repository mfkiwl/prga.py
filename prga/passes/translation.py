# -*- encoding: ascii -*-
# Python 2 and 3 compatible
from __future__ import division, absolute_import, print_function
from prga.compatible import *

from .base import AbstractPass
from ..netlist.module.module import Module
from ..netlist.module.util import ModuleUtils
from ..netlist.net.common import PortDirection
from ..netlist.net.util import NetUtils
from ..core.common import ModuleClass, NetClass, IOType, ModuleView, SegmentID, BlockPinID, Position
from ..util import Abstract, Object, uno
from ..exception import PRGAInternalError, PRGAAPIError

from abc import abstractmethod
from itertools import chain
from networkx.exception import NetworkXError

import logging
_logger = logging.getLogger(__name__)

__all__ = ['AbstractSwitchDatabase', 'TranslationPass']

# ----------------------------------------------------------------------------
# -- Switch Database ---------------------------------------------------------
# ----------------------------------------------------------------------------
class AbstractSwitchDatabase(Abstract):
    """Switch database supplying logical switch modules for instantiation."""

    # == low-level API =======================================================
    # -- properties/methods to be implemented/overriden by subclasses --------
    @abstractmethod
    def get_switch(self, width, module = None):
        """Get a switch module with ``width`` input bits.

        Args:
            width (:obj:`int`): Number of inputs needed
            module (`Module`): The module in which the switch is going to be added

        Returns:
            `Module`: Switch module found

        Note:
            The returned switch could have more than ``width`` input bits
        """
        raise NotImplementedError

# ----------------------------------------------------------------------------
# -- Translation Pass --------------------------------------------------------
# ----------------------------------------------------------------------------
class TranslationPass(Object, AbstractPass):
    """Translate modules in user view to logical view.

    Args:
        top (`Module`): Top-level array in user view. The top array from the context is selected by default

    Keyword Args:
        create_blackbox_for_undefined_primitives (:obj:`bool`): `TranslationPass` does not know how to translate
            primitives. By default, if the logical view is not defined for a primitive, an error is raised.
            If ``create_blackbox_for_undefined_primitives`` is set to ``True``, an empty logical view is created in
            this case.
    """

    __slots__ = ['top', 'create_blackbox_for_undefined_primitives']
    def __init__(self, top = None, *, create_blackbox_for_undefined_primitives = False):
        self.top = top
        self.create_blackbox_for_undefined_primitives = create_blackbox_for_undefined_primitives

    @classmethod
    def _u2l(cls, logical_model, user_ref):
        # "_logical_cp" mapping is a mapping from user node reference to logical node reference
        # both input and output reference are coalesced if and only if ``user_model`` coalesces connections
        d = getattr(logical_model, "_logical_cp", None)
        if d is None:
            return user_ref
        else:
            return d.get(user_ref, user_ref)

    @classmethod
    def _l2u(cls, logical_model, logical_ref):
        d = getattr(logical_model, "_user_cp", None)
        if d is None:
            return logical_ref
        else:
            return d.get(logical_ref, logical_ref)

    @classmethod
    def _register_u2l(cls, logical_model, user_net, logical_net, coalesced = False):
        user_node = NetUtils._reference(user_net, coalesced = coalesced)
        logical_node = NetUtils._reference(logical_net, coalesced = coalesced)
        # user -> logical
        try:
            d = logical_model._logical_cp
        except AttributeError:
            d = logical_model._logical_cp = {}
        d[user_node] = logical_node
        # logical -> user
        try:
            d = logical_model._user_cp
        except AttributeError:
            d = logical_model._user_cp = {}
        d[logical_node] = user_node

    @property
    def key(self):
        return "translation"

    def _process_module(self, module, context, *, disable_coalesce = False, is_top = False):
        # shortcut if the module is already processed
        logical = context._database.get((ModuleView.logical, module.key))
        if logical is not None:
            return logical
        # make sure the user module is tranlatible
        if not (module.module_class.is_cluster or
                module.module_class.is_block or
                module.module_class.is_routing_box or
                module.module_class.is_tile or
                module.module_class.is_array): 
            if self.create_blackbox_for_undefined_primitives and module.module_class.is_primitive:
                pass
            else:
                raise PRGAInternalError("Cannot translate module '{}'. Its module class is {:r}"
                        .format(module, module.module_class))
        # prepare the arguments for creating a new module
        kwargs = {
                'view': ModuleView.logical,
                'module_class': module.module_class,
                'key': module.key,
                }
        if not disable_coalesce and module._coalesce_connections:
            kwargs['coalesce_connections'] = True
        # propagate primitive_class
        if module.module_class.is_primitive:
            kwargs["primitive_class"] = module.primitive_class
        # special case for IO block
        if module.module_class.is_io_block:
            assert not module._coalesce_connections
            logical = Module(module.name, **kwargs)
            i, o = map(module.instances['io'].pins.get, ('inpad', 'outpad'))
            if i:
                self._register_u2l(logical, i, ModuleUtils.create_port(
                        logical, '_ipin', 1, PortDirection.input_, net_class = NetClass.io, key = IOType.ipin))
            if o:
                self._register_u2l(logical, o, ModuleUtils.create_port(
                        logical, '_opin', 1, PortDirection.output, net_class = NetClass.io, key = IOType.opin))
            if i and o:
                ModuleUtils.create_port(logical, '_oe', 1, PortDirection.output, net_class = NetClass.io,
                        key = IOType.oe)
        else:
            logical = Module(module.name, **kwargs)
        # translate ports
        globals_ = {}
        for port in itervalues(module.ports):
            net_class = None
            if module.module_class.is_primitive or module.module_class.is_cluster:
                net_class = NetClass.user
            elif module.module_class.is_block:
                if hasattr(port, 'global_'):
                    net_class = NetClass.global_
                else:
                    net_class = NetClass.block
            elif module.module_class.is_routing_box:
                if port.key.node_type.is_segment:
                    net_class = NetClass.segment
                else:
                    net_class = NetClass.bridge
            elif module.module_class.is_array or module.module_class.is_tile:
                if hasattr(port, 'global_'):
                    if is_top:
                        if not port.global_.is_bound:
                            raise PRGAInternalError("Global wire '{}' not bound to an IO block yet"
                                    .format(port.global_.name))
                        globals_[port.global_.bound_to_position, port.global_.bound_to_subtile] = port
                        continue
                    net_class = NetClass.global_
                else:
                    net_class = NetClass.bridge
            if net_class is None:
                raise NotImplementedError("Could not deduct net class of {}".format(port))
            ModuleUtils.create_port(logical, port.name, len(port), port.direction,
                    key = port.key, is_clock = port.is_clock, net_class = net_class)
        # translate instances
        for instance in itervalues(module.instances):
            # skip user-only instance in IO block: "io"
            if instance.name == 'io' and module.module_class.is_io_block:
                continue
            logical_model = self._process_module(instance.model, context,
                    disable_coalesce = disable_coalesce or not logical._coalesce_connections)
            logical_instance = ModuleUtils.instantiate(logical, logical_model, instance.name, key = instance.key)
            # special processing for IO blocks in arrays
            if logical_model.module_class.is_io_block:
                for iotype in IOType:
                    if (pin := logical_instance.pins.get(iotype)) is None:
                        continue
                    port = ModuleUtils.create_port(logical,
                            '{}_x0y0_{:d}'.format(iotype.name, instance.key), len(pin), pin.model.direction,
                            key = (iotype, Position(0, 0), instance.key), net_class = NetClass.io)
                    if port.direction.is_input:
                        global_ = globals_.pop( port.key[1:], None )
                        if global_ is not None:
                            self._register_u2l(logical, global_, port, module._coalesce_connections)
                        NetUtils.connect(port, pin)
                    else:
                        NetUtils.connect(pin, port)
            # and also IO pins of arrays
            elif logical_model.module_class.is_array or logical_model.module_class.is_tile:
                for key, pin in iteritems(logical_instance.pins):
                    if not pin.model.net_class.is_io:
                        continue
                    iotype, pos, subtile = newkey = key[0], key[1] + instance.key, key[2]
                    port = ModuleUtils.create_port(logical, "{}_x{}y{}_{:d}".format(iotype.name, *pos, subtile),
                            len(pin), pin.model.direction, key = newkey, net_class = NetClass.io)
                    if port.direction.is_input:
                        global_ = globals_.pop( port.key[1:], None )
                        if global_ is not None:
                            self._register_u2l(logical, global_, port, module._coalesce_connections)
                        NetUtils.connect(port, pin)
                    else:
                        NetUtils.connect(pin, port)
        # raise error for unbound globals
        for port in itervalues(globals_):
            raise PRGAInternalError("Global wire '{}' bound to subtile {} at {} but no IO input found there"
                    .format(port.global_.name, port.global_.bound_to_subtile, port.global_.bound_to_position))
        # translate connections
        if module.module_class.is_primitive:
            pass
        elif not module._allow_multisource:
            if module._coalesce_connections is logical._coalesce_connections:
                for u, v in module._conn_graph.edges:
                    logical._conn_graph.add_edge(self._u2l(logical, u), self._u2l(logical, v))
            else:   # module._coalesce_connections and not logical._coalesce_connections
                for u, v in module._conn_graph.edges:
                    lu, lv = map(lambda x: NetUtils._dereference(logical, self._u2l(logical, x), coalesced = True),
                            (u, v))
                    NetUtils.connect(lu, lv)
        else:       # module._coalesce_connections is False
            for net in chain(itervalues(module.ports),
                    iter(pin for instance in itervalues(module.instances) for pin in itervalues(instance.pins))):
                if not net.is_sink:
                    continue
                for bit in net:
                    user_sink = NetUtils._reference(bit)
                    try:
                        user_sources = tuple(module._conn_graph.predecessors( user_sink ))
                    except NetworkXError:
                        user_sources = tuple()
                    if len(user_sources) == 0:
                        continue
                    logical_sink = self._u2l(logical, user_sink)
                    if len(user_sources) == 1:
                        logical._conn_graph.add_edge(self._u2l(logical, user_sources[0]), logical_sink)
                        continue
                    bit = NetUtils._dereference(logical, logical_sink)
                    switch_model = context.switch_database.get_switch(len(user_sources), logical)
                    switch_name = ["_sw"]
                    if bit.bus_type.is_slice:
                        if bit.net_type.is_pin:
                            switch_name.append( bit.bus.instance.name )
                            switch_name.append( bit.bus.model.name )
                        else:
                            switch_name.append( bit.bus.name )
                        switch_name.append( str(bit.index.start) )
                    else:
                        if bit.net_type.is_pin:
                            switch_name.append( bit.instance.name )
                            switch_name.append( bit.model.name )
                        else:
                            switch_name.append( bit.name )
                    switch = ModuleUtils.instantiate(logical, switch_model, "_".join(switch_name),
                            key = (ModuleClass.switch, ) + logical_sink)
                    for user_source, switch_input in zip(user_sources, switch.pins['i']):
                        logical._conn_graph.add_edge(self._u2l(logical, user_source),
                                NetUtils._reference(switch_input))
                    logical._conn_graph.add_edge(NetUtils._reference(switch.pins['o']), logical_sink)
        context._database[ModuleView.logical, module.key] = logical
        _logger.info("Translated: {}".format(module))
        return logical

    def run(self, context, renderer = None):
        top = uno(self.top, context.top)
        if top is None:
            raise PRGAAPIError("Top-level array not set yet.")
        # recursively process modules
        system_top = self._process_module(top, context, is_top = True)
        if top is context.top:
            context.system_top = system_top
