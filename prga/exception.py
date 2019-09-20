# -*- encoding: ascii -*-
# Python 2 and 3 compatible
"""PRGA's exception and error types."""

from __future__ import division, absolute_import, print_function
from prga.compatible import *

from typing import List

__all__ = ["PRGAInternalError", "PRGAAPIError"]     # type: List[str]

class PRGAInternalError(RuntimeError):
    '''Critical internal error within PRGA flow.

    As an API user, you should never see this type of exception. If you get such an error, please email
    angl@princeton.edu with a detailed description and an example to repeat this error. We thank you for help
    developing PRGA!
    '''
    pass

class PRGAAPIError(PRGAInternalError):
    """An error of an API misuse.

    This error is thrown when the API is not used correctly.
    """
    pass
