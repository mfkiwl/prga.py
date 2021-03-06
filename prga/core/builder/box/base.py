# -*- encoding: ascii -*-
# Python 2 and 3 compatible
from __future__ import division, absolute_import, print_function
from prga.compatible import *

from ..base import BaseBuilder
from ....netlist.net.util import NetUtils
from ....exception import PRGAInternalError

__all__ = []

# ----------------------------------------------------------------------------
# -- Base Builder for Routing Boxes ------------------------------------------
# ----------------------------------------------------------------------------
class BaseRoutingBoxBuilder(BaseBuilder):
    """Base class for routing box builders.

    Args:
        context (`Context`): The context of the builder
        module (`Module`): The module to be built
    """

    # == internal API ========================================================
    # -- properties/methods to be overriden by subclasses --------------------
    @classmethod
    def _node_name(cls, node):
        """Generate the name for ``node``."""
        if node.node_type.is_block:
            return 'bp_{}{}{}{}i{}_{}'.format(
                'x' if node.position.x >= 0 else 'u', abs(node.position.x),
                'y' if node.position.y >= 0 else 'v', abs(node.position.y),
                node.subtile,
                node.prototype.name)
        elif node.node_type.is_segment:
            return 'so_{}{}{}{}{}_{}'.format(
                'x' if node.position.x >= 0 else 'u', abs(node.position.x),
                'y' if node.position.y >= 0 else 'v', abs(node.position.y),
                node.orientation.name[0],
                node.prototype.name)
        elif node.node_type.is_bridge:
            prefix = node.bridge_type.case(
                    regular_input = 'bi',
                    regular_output = 'bo',
                    cboxout = 'cu',
                    cboxout2 = 'cv')
            return '{}_{}{}{}{}{}_{}'.format(prefix,
                'x' if node.position.x >= 0 else 'u', abs(node.position.x),
                'y' if node.position.y >= 0 else 'v', abs(node.position.y),
                node.orientation.name[0],
                node.prototype.name)
        else:
            raise PRGAInternalError("Unknown node type: {}".format(node))

    # == high-level API ======================================================
    def connect(self, sources, sinks, *, fully = False):
        """Connect ``sources`` to ``sinks``.
        
        Args:
            sources: Source nets, i.e., an input port, a subset of an input port, or a list of a combination of the
                above
            sinks: Sink nets, i.e., an output port, a subset of an output port, or a list of a combination of the
                above

        Keyword Args:
            fully (:obj:`bool`): If set to ``True``, connections are made between every source and every sink
        """
        NetUtils.connect(sources, sinks, fully = fully)
