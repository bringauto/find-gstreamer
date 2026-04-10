# Config-file package entry point for the BA GStreamer finder.
#
# Set the ``GStreamer_DIR`` environment variable to the directory containing
# this file, then use the standard::
#
#  find_package(GStreamer REQUIRED)

include("${CMAKE_CURRENT_LIST_DIR}/FindGStreamer.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/Tools.cmake")
