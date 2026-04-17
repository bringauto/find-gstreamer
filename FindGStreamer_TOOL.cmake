# FindGStreamer_TOOL_FIX_PKGCONFIG(DIR <dir>)
#
# Rewrites all .pc files under <dir> in-place, replacing the hard-coded
# ``/INSTALL`` prefix with the actual <dir> path. Use this before
# find_package(GStreamer) when the SDK was built with a fixed install prefix
# that differs from where it is located at build time.
FUNCTION(FindGStreamer_TOOL_FIX_PKGCONFIG)
    CMAKE_PARSE_ARGUMENTS(_bfp "" "DIR" "" ${ARGN})
    IF(NOT _bfp_DIR)
        MESSAGE(FATAL_ERROR "FindGStreamer_TOOL_FIX_PKGCONFIG: DIR is required")
    ENDIF()

    FILE(GLOB_RECURSE PC_FILES "${_bfp_DIR}/*.pc")

    FOREACH(pc_file IN LISTS PC_FILES)
        FILE(READ "${pc_file}" pc_content)
        STRING(REPLACE "/INSTALL" "${_bfp_DIR}" pc_content_fixed "${pc_content}")
        FILE(WRITE "${pc_file}" "${pc_content_fixed}")
    ENDFOREACH()
ENDFUNCTION()

# FindGStreamer_TOOL_INSTALL_AND_PATCHELF_PLUGINS(TARGETS <targets...> DESTINATION <dir>)
#
# Installs all given <targets> to <dir> and runs
# ``patchelf --set-rpath $ORIGIN/..`` on each installed plugin .so so that
# plugins can locate their shared library dependencies in the adjacent lib/
# directory at runtime. Requires patchelf to be present on the install host.
FUNCTION(FindGStreamer_TOOL_INSTALL_AND_PATCHELF_PLUGINS)
    CMAKE_PARSE_ARGUMENTS(_gip "" "DESTINATION" "TARGETS" ${ARGN})
    IF(NOT _gip_DESTINATION)
        MESSAGE(FATAL_ERROR "FindGStreamer_TOOL_INSTALL_AND_PATCHELF_PLUGINS: DESTINATION is required")
    ENDIF()
    IF(NOT _gip_TARGETS)
        MESSAGE(FATAL_ERROR "FindGStreamer_TOOL_INSTALL_AND_PATCHELF_PLUGINS: TARGETS is required")
    ENDIF()

    FIND_PROGRAM(_gip_PATCHELF patchelf REQUIRED)

    INSTALL(IMPORTED_RUNTIME_ARTIFACTS ${_gip_TARGETS}
        LIBRARY DESTINATION "${_gip_DESTINATION}"
    )

    SET(_gip_dest "${_gip_DESTINATION}")
    INSTALL(CODE "
        FILE(GLOB _plugins \"\${CMAKE_INSTALL_PREFIX}/${_gip_dest}/libgst*.so\")
        FOREACH(_p IN LISTS _plugins)
            GET_FILENAME_COMPONENT(_pname \"\${_p}\" NAME)
            MESSAGE(STATUS \"patchelf update R/RUNPATH: ${_gip_dest}/\${_pname}\")
            EXECUTE_PROCESS(COMMAND \"${_gip_PATCHELF}\" --set-rpath \"\$ORIGIN/..\" \"\${_p}\" COMMAND_ERROR_IS_FATAL ANY)
        ENDFOREACH()
    ")
ENDFUNCTION()
