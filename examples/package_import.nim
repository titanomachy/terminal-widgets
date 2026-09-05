## Compile this package-foundation example with:
##
## .. code-block:: console
##   nim c --path:src examples/package_import.nim

{.warning[UnusedImport]: off.}
from terminal_widgets import nil

echo "TerminalWidgets package facade imported successfully."
