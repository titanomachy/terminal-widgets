## Compile this package-foundation example with:
##
## .. code-block:: console
##   nim c --path:src examples/package_import.nim
##
## The repository configuration writes the resulting executable to
## ``build/bin`` and compiler cache entries to ``build/nimcache``. The same
## policy applies when this example is compiled from inside ``examples/``.

{.warning[UnusedImport]: off.}
from terminal_widgets import nil

echo "TerminalWidgets package facade imported successfully."
