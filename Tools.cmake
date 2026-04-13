FUNCTION(BA_FIX_PKGCONFIG CHANGE_DIR)
    FILE(GLOB_RECURSE PC_FILES "${CHANGE_DIR}/*.pc")

    FOREACH(pc_file IN LISTS PC_FILES)
        FILE(READ "${pc_file}" pc_content)
        STRING(REPLACE "/INSTALL" "${CHANGE_DIR}" pc_content_fixed "${pc_content}")
        FILE(WRITE "${pc_file}" "${pc_content_fixed}")
    ENDFOREACH()
ENDFUNCTION()

FUNCTION(BA_INSTALL_AND_PATCHELF_GSTREAMER_PLUGINS)
    CMAKE_PARSE_ARGUMENTS(_gip "" "DESTINATION" "" ${ARGN})
    IF(NOT _gip_DESTINATION)
        MESSAGE(FATAL_ERROR "BA_INSTALL_AND_PATCHELF_GSTREAMER_PLUGINS: DESTINATION is required")
    ENDIF()

    INSTALL(IMPORTED_RUNTIME_ARTIFACTS ${GStreamer_PLUGIN_TARGETS}
        LIBRARY DESTINATION "${_gip_DESTINATION}"
    )

    SET(_gip_dest "${_gip_DESTINATION}")
    INSTALL(CODE "
        FILE(GLOB _plugins \"\${CMAKE_INSTALL_PREFIX}/${_gip_dest}/libgst*.so\")
        FOREACH(_p IN LISTS _plugins)
            GET_FILENAME_COMPONENT(_pname \"\${_p}\" NAME)
            MESSAGE(STATUS \"patchelf update R/RUNPATH: ${_gip_dest}/\${_pname}\")
            EXECUTE_PROCESS(COMMAND patchelf --set-rpath \"\$ORIGIN/..\" \"\${_p}\")
        ENDFOREACH()
    ")
ENDFUNCTION()
