# -*- encoding: ascii -*-
# Python 2 and 3 compatible
from __future__ import division, absolute_import, print_function
from prga.compatible import *

from prga.util import Enum

__all__ = ['NetType', 'ConstNetType', 'PortDirection', 'NetClass', 'RoutingNodeType']

# ----------------------------------------------------------------------------
# -- Net Type ----------------------------------------------------------------
# ----------------------------------------------------------------------------
class NetType(Enum): 
    """Enum type for nets.

    In PRGA, only ports/pins are modeled. Wires are only created during RTL generation, and not modeled in our
    in-memory data structure.
    """
    # constant net types
    const = 0           #: constant net
    # netlist net types
    port = 1            #: ports of a module
    pin = 2             #: ports of an instantiated sub-module

# ----------------------------------------------------------------------------
# -- Constant Net Type -------------------------------------------------------
# ----------------------------------------------------------------------------
class ConstNetType(Enum):
    """Enum type for constant nets."""
    unconnected = 0     #: unconnected
    zero = 1            #: tied to constant logic 0
    one = 2             #: tied to constant logic 1

# ----------------------------------------------------------------------------
# -- Port Direction ----------------------------------------------------------
# ----------------------------------------------------------------------------
class PortDirection(Enum):
    """Enum type for port/pin directions."""
    input_ = 0  #: input direction
    output = 1  #: output direction

    @property
    def opposite(self):
        """The opposite of the this direction.

        Returns:
            `PortDirection`: the enum value of the opposite direction.
        """
        return self.case(PortDirection.output, PortDirection.input_)

# ----------------------------------------------------------------------------
# -- Logical Net Class -------------------------------------------------------
# ----------------------------------------------------------------------------
class NetClass(Enum):
    """Logical class for nets."""
    primitive = 0           #: user-available primitive ports
    switch = 1              #: switch input/output
    config = 2              #: configuration input/output
    multimode = 3           #: input/output of a multimode primitive
    mode = 4                #: input/output of a mode of a multimode primitive
    cluster = 5             #: user-defined input/output of a sub-block cluster
    # routing nodes
    blockport = 6           #: IPIN/OPIN of logic/io block
    node = 7                #: other routing nodes
    # other tile/array ports
    io = 8                  #: IOB/array external ports
    global_ = 9             #: global wires
    # extensions
    extension = 10          #: reserved for extensions

# ----------------------------------------------------------------------------
# -- Routing Node Type -------------------------------------------------------
# ----------------------------------------------------------------------------
class RoutingNodeType(Enum):
    """Routing node type."""
    segment_driver = 0      #: SegmentID
    segment_bridge = 1      #: SegmentBridgeID
    blockport_bridge = 2    #: BlockportBridgeID
