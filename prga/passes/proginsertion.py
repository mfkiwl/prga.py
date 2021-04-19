# -*- encoding: ascii -*-

from .base import AbstractPass

__all__ = ['ProgCircuitryInsertion']

# ----------------------------------------------------------------------------
# -- Programming Circuitry Insertion Pass ------------------------------------
# ----------------------------------------------------------------------------
class ProgCircuitryInsertion(AbstractPass):
    """Insert programming circuitry."""

    __slots__ = ['_args', '_kwargs']

    def __init__(self, *args, **kwargs):
        self._args = args
        self._kwargs = kwargs

    @property
    def key(self):
        return "prog.insertion"

    @property
    def dependences(self):
        return ("annotation.switch_path", )

    @property
    def passes_after_self(self):
        return ("rtl", )

    def run(self, context):
        context.prog_entry.insert_prog_circuitry(context, *self._args, **self._kwargs)
