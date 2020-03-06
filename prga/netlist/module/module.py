# -*- encoding: ascii -*-
# Python 2 and 3 compatible
from __future__ import division, absolute_import, print_function
from prga.compatible import *

from .common import AbstractModule
from ..net.common import NetType
from ...util import Object, ReadonlyMappingProxy, uno
from ...exception import PRGAInternalError

from collections import OrderedDict
from enum import Enum
import networkx as nx

__all__ = ['Module']

# ----------------------------------------------------------------------------
# -- Memory-optimized Connection Graph ---------------------------------------
# ----------------------------------------------------------------------------
class _Placeholder(Enum):
    placeholder = 0

class _MemoptBitwiseConnGraphDict(MutableMapping):
    __slots__ = ['_d']
    def __init__(self):
        self._d = {}

    def __getitem__(self, k):
        idx, key = k[0], k[1:]
        try:
            v = self._d[key][idx]
        except (KeyError, IndexError):
            raise KeyError(k)
        if v is _Placeholder.placeholder:
            raise KeyError(k)
        else:
            return v

    def __setitem__(self, k, v):
        idx, key = k[0], k[1:]
        try:
            l = self._d[key]
        except KeyError:
            self._d[key] = tuple(_Placeholder.placeholder for i in range(idx)) + (v, )
            return
        if len(l) > idx:
            self._d[key] = tuple(v if i == idx else item for i, item in enumerate(l))
        else:
            self._d[key] = tuple(l[i] if i < len(l) else _Placeholder.placeholder for i in range(idx)) + (v, )

    def __delitem__(self, k):
        idx, key = k[0], k[1:]
        l = self._d[key]
        if idx >= len(l):
            raise KeyError(k)
        self._d[key] = tuple(_Placeholder.placeholder if i == idx else item for i, item in enumerate(l))

    def __len__(self, k):
        return sum(1 for _ in iter(self))

    def __iter__(self):
        for k, l in iteritems(self._d):
            for idx, v in enumerate(l):
                if v is not _Placeholder.placeholder:
                    yield (idx, ) + k

class _LazyDict(MutableMapping):
    __slots__ = ['_d']

    def __getitem__(self, k):
        if k in self.__slots__:
            try:
                return getattr(self, k)
            except AttributeError:
                raise KeyError(k)
        else:
            try:
                return self._d[k]
            except AttributeError:
                raise KeyError(k)

    def __setitem__(self, k, v):
        if k in self.__slots__:
            setattr(self, k, v)
        else:
            try:
                self._d[k] = v
            except AttributeError:
                self._d = {k: v}

    def __delitem__(self, k):
        if k in self.__slots__:
            try:
                delattr(self, k)
            except AttributeError:
                raise KeyError(k)
        else:
            try:
                del self._d[k]
            except AttributeError:
                raise KeyError(k)

    def __len__(self):
        base = sum(1 for attr in self.__slots__ if hasattr(self, attr))
        try:
            return base + len(self._d)
        except AttributeError:
            return base

    def __iter__(self):
        for attr in self.__slots__:
            if hasattr(self, attr):
                yield attr
        try:
            for k in self._d:
                yield k
        except AttributeError:
            return

class _NodeAttrDict(_LazyDict):
    __slots__ = ['clock_group', 'clock', 'min_setup', 'max_setup', 'min_hold', 'max_setup', 'min_clk2q', 'max_clk2q']

class _EdgeAttrDict(_LazyDict):
    __slots__ = ['min_delay', 'max_delay']

class _GraphAttrDict(_LazyDict):
    __slots__ = ['clock_groups']

class _CoalescedConnGraph(nx.DiGraph):
    node_attr_dict_factory = _NodeAttrDict
    edge_attr_dict_factory = _EdgeAttrDict
    graph_attr_dict_factory = _GraphAttrDict

class _MemoptConnGraph(_CoalescedConnGraph):
    node_dict_factory = _MemoptBitwiseConnGraphDict
    adjlist_outer_dict_factory = _MemoptBitwiseConnGraphDict

# ----------------------------------------------------------------------------
# -- Module ------------------------------------------------------------------
# ----------------------------------------------------------------------------
class Module(Object, AbstractModule):
    """A netlist module.

    Args:
        name (:obj:`str`): Name of the module

    Keyword Args:
        key (:obj:`Hashable`): A hashable key used to index this module in the database. If not given \(default
            argument: ``None``\), ``name`` is used by default
        ports (:obj:`Mapping`): A mapping object used to index ports by keys. ``None`` by default, which disallows
            ports to be added into this module
        instances (:obj:`Mapping`): A mapping object used to index instances by keys. ``None`` by default, which
            disallows instances to be added into this module
        conn_graph (`networkx.DiGraph`_): Connection & Timing Graph. It's strongly recommended to subclass
            `networkx.DiGraph`_ to optimize memory usage
        allow_multisource (:obj:`bool`): If set, a sink net may be driven by multiple source nets. Incompatible with
            ``coalesce_connections``
        coalesce_connections (:obj:`bool`): If set, all connections are made at the granularity of buses.
            Incompatible with ``allow_multisource``.
        **kwargs: Custom key-value arguments. For each key-value pair ``key: value``, ``setattr(self, key, value)``
            is executed at the BEGINNING of ``__init__``

    .. _networkx.DiGraph: https://networkx.github.io/documentation/stable/reference/classes/digraph.html#networkx.DiGraph
    """

    __slots__ = ['_name', '_key', '_children', '_ports', '_instances', '_conn_graph',
            '_allow_multisource', '_coalesce_connections', '__dict__']

    # == internal API ========================================================
    def __init__(self, name, *,
            key = None, ports = None, instances = None, conn_graph = None,
            allow_multisource = False, coalesce_connections = False, **kwargs):
        if allow_multisource and coalesce_connections:
            raise PRGAInternalError("`allow_multisource` and `coalesce_connections` are incompatible")
        self._name = name
        self._key = uno(key, name)
        self._children = OrderedDict()  # Mapping from names to children (ports and instances)
        if ports is not None:
            self._ports = ports
        if instances is not None:
            self._instances = instances
        self._allow_multisource = allow_multisource
        self._coalesce_connections = coalesce_connections
        self._conn_graph = uno(conn_graph, nx.DiGraph())
        for k, v in iteritems(kwargs):
            setattr(self, k, v)

    def __str__(self):
        return 'Module({})'.format(self.name)

    # == low-level API =======================================================
    def _add_port(self, port):
        """Add ``port`` into this module.

        Args:
            port (`AbstractPort`):
        """
        # check parent of the port
        if port.parent is not self:
            raise PRGAInternalError("Module '{}' is not the parent of '{}'".format(self, port))
        # check name conflict
        if port.name in self._children:
            raise PRGAInternalError("Name '{}' taken by {} in module '{}'"
                    .format(port.name, self._children[port.name], self))
        # check ports modifiable and key conflict
        try:
            value = self._ports.setdefault(port.key, port)
            if value is not port:
                raise PRGAInternalError("Port key '{}' taken by {} in module '{}'".format(port.key, value, self))
        except AttributeError:
            raise PRGAInternalError("Cannot add '{}' to module '{}'".format(port, self))
        # add port to children mapping
        return self._children.setdefault(port.name, port)

    def _add_instance(self, instance):
        """Add ``instance`` into this module.

        Args:
            instance (`AbstractInstance`):
        """
        # check parent of the instance
        if instance.parent is not self:
            raise PRGAInternalError("Module '{}' is not the parent of '{}'".format(self, instance))
        # check name conflict
        if instance.name in self._children:
            raise PRGAInternalError("Name '{}' taken by {} in module '{}'"
                    .format(instance.name, self._children[net.name], self))
        # check instances modifiable and key conflict
        try:
            value = self._instances.setdefault(instance.key, instance)
            if value is not instance:
                raise PRGAInternalError("Instance key '{}' taken by {} in module '{}'"
                        .format(instance.key, value, self))
        except AttributeError:
            raise PRGAInternalError("Cannot add '{}' to module '{}'".format(instance, self))
        # add instance to children mapping
        return self._children.setdefault(instance.name, instance)

    # -- implementing properties/methods required by superclass --------------
    @property
    def name(self):
        return self._name

    @property
    def key(self):
        return self._key

    @property
    def children(self):
        return ReadonlyMappingProxy(self._children)

    @property
    def ports(self):
        try:
            return ReadonlyMappingProxy(self._ports)
        except AttributeError:
            return ReadonlyMappingProxy({})

    @property
    def instances(self):
        try:
            return ReadonlyMappingProxy(self._instances)
        except AttributeError:
            return ReadonlyMappingProxy({})