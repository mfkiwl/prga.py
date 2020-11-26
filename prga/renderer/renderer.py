# -*- encoding: ascii -*-

from ..netlist import NetUtils
from ..util import uno
from ..exception import PRGAInternalError

import os
import jinja2 as jj

__all__ = ['FileRenderer']

# ----------------------------------------------------------------------------
# -- File Renderer -----------------------------------------------------------
# ----------------------------------------------------------------------------
class FileRenderer(object):
    """File renderer based on Jinja2."""

    __slots__ = ['template_search_paths', 'tasks', '_yosys_synth_script_task']
    def __init__(self, *paths):
        self.template_search_paths = [os.path.join(os.path.dirname(os.path.abspath(__file__)), 'templates'),
                os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "integration", "templates")]
        self.template_search_paths = list(iter(paths)) + self.template_search_paths
        self.tasks = {}
        self._yosys_synth_script_task = None

    @classmethod
    def _net2verilog(cls, net):
        """:obj:`str`: Render ``net`` in verilog syntax."""
        if net.net_type.is_const:
            if net.value is None:
                return "{}'bx".format(len(net))
            else:
                return "{}'h{:x}".format(len(net), net.value)
        elif net.net_type.is_concat:
            return '{' + ',\n'.join(cls._net2verilog(i) for i in reversed(net.items)) + '}'
        elif net.net_type.is_slice:
            return '{}[{}:{}]'.format(cls._net2verilog(net.bus), net.index.stop - 1, net.index.start)
        elif net.net_type.is_bit:
            return '{}[{}]'.format(cls._net2verilog(net.bus), net.index)
        elif net.net_type.is_port:
            return net.name
        elif net.net_type.is_pin:
            return "_{}__{}".format(net.instance.name, net.model.name)
        else:
            raise PRGAInternalError("Unsupported net: {}".format(net))

    @classmethod
    def _source2verilog(cls, net):
        """:obj:`str`: Render in verilog syntax the concatenation for the nets driving ``net``."""
        return cls._net2verilog(NetUtils.get_source(net, return_const_if_unconnected = True))

    def _get_yosys_script_task(self, script_file = None):
        """Get the specified or most recently added yosys script rending task."""
        if (script_file := uno(script_file, self._yosys_synth_script_task)) is None:
            raise PRGAInternalError("Main synthesis script not specified")
        script_task = self.tasks[script_file]
        if len(script_task) > 1:
            raise PRGAInternalError("Main synthesis script is produced by multiple templates")
        return script_file, script_task

    def add_verilog(self, file_, module, template = None, **kwargs):
        """Add a Verilog rendering task.

        Args:
            file_ (:obj:`str` of file-like object): The output file
            module (`Module`): The module to be rendered
            template (:obj:`str`): The template to be used
            **kwargs: Additional key-value parameters to be passed into the template when rendering
        """
        parameters = {
                "module": module,
                "source2verilog": self._source2verilog,
                }
        parameters.update(kwargs)
        self.tasks.setdefault(file_, []).append( (uno(template, "generic/module.tmpl.v"), parameters) )

    def add_generic(self, file_, template, **kwargs):
        """Add a generic file rendering task.

        Args:
            file_ (:obj:`str` of file-like object): The output file
            template (:obj:`str`): The template to be used
            **kwargs: Additional key-value parameters to be passed into the template when rendering
        """
        self.tasks.setdefault(file_, []).append( (template, kwargs) )

    def add_yosys_synth_script(self, file_, lut_sizes, template = None, **kwargs):
        """Add a yosys synthesis script rendering task.

        Args:
            file_ (:obj:`str` of file-like object): The output file
            lut_sizes (:obj:`Sequence` [:obj:`int` ]): LUT sizes active in the FPGA
            template (:obj:`str`): The template to be used
            **kwargs: Additional key-value parameters to be passed into the template when rendering
        """
        parameters = {
                "libraries": [],
                "memory_techmaps": [],
                "techmaps": [],
                "lut_sizes": lut_sizes,
                }
        parameters.update(kwargs)
        self.tasks.setdefault(file_, []).append( (uno(template, "generic/synth.tmpl.tcl"), parameters) )
        self._yosys_synth_script_task = file_

    def add_yosys_library(self, file_, module, template = None, script_file = None, **kwargs):
        """Add a yosys library rendering task.

        Args:
            file_ (:obj:`str` of file-like object): The output file
            module (`Module`): The blackbox module

        Keyword Args:
            template (:obj:`str`): The template to be used
            script_file (:obj:`str` of file-like object): The main script file. If not specified, the most recently
                added yosys script file will be used
            **kwargs: Additional key-value parameters to be passed into the template when rendering
        """
        parameters = {
                "module": module,
                }
        parameters.update(kwargs)
        self.tasks.setdefault(file_, []).append( (uno(template, "generic/blackbox.lib.tmpl.v"), parameters) )
        script_file, script_task = self._get_yosys_script_task(script_file)
        if not isinstance(file_, str):
            file_ = file_.name
        if not os.path.isabs(file_) and not os.path.isabs(script_file):
            file_ = os.path.relpath(file_, os.path.dirname(script_file))
        if file_ not in script_task[0][1]["libraries"]:
            script_task[0][1]["libraries"].append( file_ )

    def add_yosys_techmap(self, file_, template, script_file = None, premap_commands = tuple(), **kwargs):
        """Add a yosys techmap rendering task.

        Args:
            file_ (:obj:`str` of file-like object): The output file
            template (:obj:`str`): The template to be used

        Keyword Args:
            script_file (:obj:`str` of file-like object): The main script file. If not specified, the most recently
                added yosys script file will be used
            premap_commands (:obj:`Sequence` [:obj:`str` ]): Commands to be run before running the techmap step
            **kwargs: Additional key-value parameters to be passed into the template when rendering
        """
        parameters = {}
        parameters.update(kwargs)
        self.tasks.setdefault(file_, []).append( (template, parameters) )
        script_file, script_task = self._get_yosys_script_task(script_file)
        if not isinstance(file_, str):
            file_ = file_.name
        if not os.path.isabs(file_) and not os.path.isabs(script_file):
            file_ = os.path.relpath(file_, os.path.dirname(script_file))
        script_task[0][1]["techmaps"].append( {
            "premap_commands": premap_commands,
            "techmap": file_,
            } )

    def add_yosys_bram_rule(self, file_, module, template = None, **kwargs):
        """Add a yosys BRAM inferring rule rendering task.

        Args:
            file_ (:obj:`str` of file-like object): The output file
            module (`Module`): The memory module
            template (:obj:`str`): The template to be used

        Keyword Args:
            **kwargs: Additional key-value parameters to be passed into the template when rendering
        """
        parameters = {
                "module": module,
                }
        parameters.update(kwargs)
        l = self.tasks.setdefault(file_, [])
        if l:
            l[-1][1].setdefault("not_last", True)
        l.append( (uno(template, "bram/tmpl.rule"), parameters) )

    def add_yosys_memory_techmap(self, file_, module, template = None, script_file = None,
            premap_commands = tuple(), rule_script = None, **kwargs):
        """Add a yosys memory techmap rendering task.

        Args:
            file_ (:obj:`str` or file-like object): The output file
            module (`Module`): The memory module

        Keyword Args:
            template (:obj:`str`): The template to be used
            script_file (:obj:`str` of file-like object): The main script file. If not specified, the most recently
                added yosys script file will be used
            premap_commands (:obj:`Sequence` [:obj:`str` ]): Commands to be run before running the techmap step
            rule_script (:obj:`str` or file-like object): The BRAM inferring rule
            **kwargs: Additional key-value parameters to be passed into the template when rendering
        """
        parameters = {
                "module": module,
                }
        parameters.update(kwargs)
        self.tasks.setdefault(file_, []).append( (uno(template, "bram/techmap.tmpl.v"), parameters) )
        script_file, script_task = self._get_yosys_script_task(script_file)
        if not isinstance(file_, str):
            file_ = file_.name
        if not os.path.isabs(file_) and not os.path.isabs(script_file):
            file_ = os.path.relpath(file_, os.path.dirname(script_file))
        d = {
                "premap_commands": premap_commands,
                "techmap": file_,
                }
        if rule_script is not None:
            if not isinstance(rule_script, str):
                rule_script = rule_script.name
            if not os.path.isabs(rule_script) and not os.path.isabs(script_file):
                rule_script = os.path.relpath(rule_script, os.path.dirname(script_file))
            d["rule"] = rule_script
        script_task[0][1]["memory_techmaps"].append( d )

    def render(self):
        """Render all added files and clear the task queue."""
        env = jj.Environment(loader = jj.FileSystemLoader(self.template_search_paths))
        while self.tasks:
            file_, l = self.tasks.popitem()
            if isinstance(file_, str):
                d = os.path.dirname(file_)
                if d:
                    os.makedirs(d, exist_ok = True)
                file_ = open(file_, "wb")
            for template, parameters in l:
                env.get_template(template).stream(parameters).dump(file_, encoding="ascii")
