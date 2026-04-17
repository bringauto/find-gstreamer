CMAKE_MINIMUM_REQUIRED(VERSION 3.19)
PROJECT(FindGStreamer)

INCLUDE(GNUInstallDirs)

SET(_gstreamer_cmake_install_dir "${CMAKE_INSTALL_DATADIR}/cmake/GStreamer")

INSTALL(FILES
    GStreamerConfig.cmake
    FindGStreamer.cmake
    FindGStreamer_TOOL.cmake
    DESTINATION "${_gstreamer_cmake_install_dir}"
)
