# SPDX-FileCopyrightText: 2024 L. E. Segovia <amy@centricular.com>
# SPDX-License-Ref: LGPL-2.1-or-later

#[=======================================================================[.rst:
FindGStreamer
-------

Finds the GStreamer library. Requires ``pkg-config`` to be installed.

Configuration
^^^^^^^^^^^^^

This module can be configured with the following variables:

``GStreamer_STATIC``
  Link against GStreamer statically (see below).

Imported Targets
^^^^^^^^^^^^^^^^

This module defines the following :prop_tgt:`IMPORTED` targets:

``GStreamer::GStreamer``
  The GStreamer library.

Result Variables
^^^^^^^^^^^^^^^^

This will define the following variables:

``GStreamer_FOUND``
  True if the system has the GStreamer library.
``GStreamer_VERSION``
  The version of the GStreamer library which was found.
``GStreamer_INCLUDE_DIRS``
  Include directories needed to use GStreamer.
``GStreamer_LIBRARIES``
  Libraries needed to link to GStreamer.

Cache Variables
^^^^^^^^^^^^^^^

The following cache variables may also be set:

``GStreamer_INCLUDE_DIR``
  The directory containing ``gst/gstversion.h``.
``GStreamer_LIBRARY``
  The path to the GStreamer library.

Configuration Variables
^^^^^^^^^^^^^^^

Setting the following variables is required, depending on the operating system:

``GStreamer_ROOT_DIR``
  Installation prefix of the GStreamer SDK.

``GStreamer_USE_STATIC_LIBS`
  Set to ON to force the use of the static libraries. Default is OFF.

``GStreamer_BUNDLE_DEPS``
  Set to ON to include ``Requires.private`` dependencies in the IMPORTED target
  graph. Use this when bundling the GStreamer SDK alongside your application so
  that ``install(IMPORTED_RUNTIME_ARTIFACTS)`` captures all runtime libraries.
  Default is OFF.

``GStreamer_EXTRA_DEPS``
  pkg-config names of the extra dependencies that will be included whenever linking against GStreamer.

#]=======================================================================]

if (GStreamer_FOUND)
    return()
endif()

#####################
#  Setup variables  #
#####################

if (NOT DEFINED GStreamer_ROOT_DIR AND DEFINED GSTREAMER_ROOT)
    set(GStreamer_ROOT_DIR ${GSTREAMER_ROOT})
endif()

if (NOT GStreamer_ROOT_DIR)
    set(GStreamer_ROOT_DIR "${CMAKE_CURRENT_LIST_DIR}/../../")
endif()

if (NOT EXISTS "${GStreamer_ROOT_DIR}")
    message(FATAL_ERROR "The directory GStreamer_ROOT_DIR=${GStreamer_ROOT_DIR} does not exist")
endif()

if (NOT DEFINED GStreamer_USE_STATIC_LIBS)
    set(GStreamer_USE_STATIC_LIBS OFF)
endif()

# When ON, pkg-config is queried with --static so that Requires.private deps
# are included in the IMPORTED target graph. Use this when bundling the
# GStreamer SDK alongside your application.
if (NOT DEFINED GStreamer_BUNDLE_DEPS)
    set(GStreamer_BUNDLE_DEPS OFF)
endif()

# Returns _LINK_LIBRARIES for the given prefix, with a VERBOSE log line.
# When GStreamer_BUNDLE_DEPS=ON, PKG_CONFIG_EXECUTABLE is modified below to
# include --static so _LINK_LIBRARIES already contains Requires.private deps.
function(_gst_dep_libs _out _prefix)
    set(${_out} "${${_prefix}_LINK_LIBRARIES}" PARENT_SCOPE)
    message(VERBOSE "  [deps] ${_prefix}: ${${_prefix}_LINK_LIBRARIES}")
endfunction()

# Set the environment for pkg-config
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    set(ENV{PKG_CONFIG_PATH} "${GStreamer_ROOT_DIR}/lib/pkgconfig;${GStreamer_ROOT_DIR}/lib/gstreamer-1.0/pkgconfig;${GStreamer_ROOT_DIR}/lib/gio/modules/pkgconfig")
    # Block pkgconf's forced relocation for non-lib/pkgconfig modules on Windows -- https://github.com/pkgconf/pkgconf/commit/dcf529b83d621ed09e99e41fc35fdffd068bd87a
    set(ENV{PKG_CONFIG_DONT_DEFINE_PREFIX} 1)
else()
    set(ENV{PKG_CONFIG_PATH} "${GStreamer_ROOT_DIR}/lib/pkgconfig:${GStreamer_ROOT_DIR}/lib/gstreamer-1.0/pkgconfig:${GStreamer_ROOT_DIR}/lib/gio/modules/pkgconfig")
endif()

# Set the list of extra dependencies
if (NOT DEFINED GStreamer_EXTRA_DEPS)
    set(GStreamer_EXTRA_DEPS)
    if (DEFINED GSTREAMER_EXTRA_DEPS)
        set(GStreamer_EXTRA_DEPS ${GSTREAMER_EXTRA_DEPS})
    endif()
endif()

# Find libraries. This is meant to be used with static libraries
# (hence the reprioritization) but I've added a fallback to shared libraries
# and stub modules in case any are non-existent.
function(_gst_find_library LOCAL_LIB GST_LOCAL_LIB)
    if (DEFINED ${GST_LOCAL_LIB})
        return()
    endif()

    set(_gst_suffixes ${CMAKE_FIND_LIBRARY_SUFFIXES})
    set(_gst_prefixes ${CMAKE_FIND_LIBRARY_PREFIXES})
    if (APPLE)
        set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".dylib" ".so" ".tbd")
        set(CMAKE_FIND_LIBRARY_PREFIXES "" "lib")
    elseif (UNIX)
        set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".so")
        set(CMAKE_FIND_LIBRARY_PREFIXES "" "lib")
    else()
        set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".lib")
        set(CMAKE_FIND_LIBRARY_PREFIXES "" "lib")
    endif()

    if ("${LOCAL_LIB}" IN_LIST _gst_IGNORED_SYSTEM_LIBRARIES)
        set(${GST_LOCAL_LIB} ${LOCAL_LIB} PARENT_SCOPE)
    else()
        find_library(${GST_LOCAL_LIB}
            ${LOCAL_LIB}
            HINTS ${ARGN}
            NO_DEFAULT_PATH
            NO_CMAKE_FIND_ROOT_PATH
            REQUIRED
        )
        set(${GST_LOCAL_LIB} "${${GST_LOCAL_LIB}}" PARENT_SCOPE)
        if (NOT ${GST_LOCAL_LIB})
            message(FATAL_ERROR "${LOCAL_LIB} was unexpectedly not found.")
        endif()
    endif()

    set(CMAKE_FIND_LIBRARY_SUFFIXES ${_gst_suffixes})
    set(CMAKE_FIND_LIBRARY_PREFIXES ${_gst_prefixes})
endfunction()

macro(_gst_apply_link_libraries HIDE PC_LIBRARIES PC_HINTS GST_TARGET)
    if (APPLE AND ${HIDE})
        target_link_directories(${GST_TARGET} INTERFACE
            ${${PC_HINTS}}
        )
    endif()
    foreach(LOCAL_LIB IN LISTS ${PC_LIBRARIES})
        if (LOCAL_LIB MATCHES "${_gst_SRT_REGEX_PATCH}")
            string(REGEX REPLACE "${_gst_SRT_REGEX_PATCH}" "\\1" LOCAL_LIB "${LOCAL_LIB}")
        endif()
        string(MAKE_C_IDENTIFIER "_gst_${LOCAL_LIB}" GST_LOCAL_LIB)
        if (NOT ${GST_LOCAL_LIB})
            _gst_find_library(${LOCAL_LIB} ${GST_LOCAL_LIB} ${${PC_HINTS}})
        endif()
        if ("${${GST_LOCAL_LIB}}" IN_LIST _gst_IGNORED_SYSTEM_LIBRARIES)
            target_link_libraries(${GST_TARGET} INTERFACE
                ${${GST_LOCAL_LIB}})
        elseif (APPLE AND ${HIDE})
            set(LOCAL_FILE)
            get_filename_component(LOCAL_FILE ${${GST_LOCAL_LIB}} NAME)
            target_link_libraries(${GST_TARGET} INTERFACE
                "-hidden-l${LOCAL_FILE}")
        elseif((UNIX OR ANDROID) AND ${HIDE})
            target_link_libraries(${GST_TARGET} INTERFACE
                -Wl,--exclude-libs,${${GST_LOCAL_LIB}})
        else()
            target_link_libraries(${GST_TARGET} INTERFACE
                ${${GST_LOCAL_LIB}})
        endif()
    endforeach()
endmacro()

macro(_gst_filter_missing_directories GST_INCLUDE_DIRS)
    set(_gst_include_dirs)
    foreach(DIR IN LISTS ${GST_INCLUDE_DIRS})
        string(MAKE_C_IDENTIFIER "${DIR}" _gst_dir_id)
        if (DEFINED _gst_exists_${_gst_dir_id})
            if (_gst_exists_${_gst_dir_id})
                list(APPEND _gst_include_dirs "${DIR}")
            endif()
        elseif (EXISTS "${DIR}")
            list(APPEND _gst_include_dirs "${DIR}")
            set(_gst_exists_${_gst_dir_id} TRUE)
        else()
            message(WARNING "Skipping missing include folder ${DIR}.")
            set(_gst_exists_${_gst_dir_id} FALSE)
        endif()
    endforeach()
    set(${GST_INCLUDE_DIRS} "${_gst_include_dirs}")
endmacro()

macro(_gst_apply_frameworks PC_STATIC_LDFLAGS_OTHER GST_TARGET)
    if (APPLE)
        # LDFLAGS_OTHER may include framework linkage. Because CMake
        # iterates over arguments separated by spaces, it doesn't realise
        # that those arguments must not be split.
        set(new_ldflags)
        set(assemble_framework FALSE)
        foreach(_arg IN LISTS ${PC_STATIC_LDFLAGS_OTHER})
            if (assemble_framework)
                set(assemble_framework FALSE)
                find_library(GST_${_arg}_LIB ${_arg} REQUIRED)
                target_link_libraries(${GST_TARGET}
                    INTERFACE
                        "${GST_${_arg}_LIB}"
                )
            elseif (_arg STREQUAL "-framework")
                set(assemble_framework TRUE)
            else()
                set(assemble_framework FALSE)
                list(APPEND new_ldflags "${_arg}")
            endif()
        endforeach()
        set_target_properties(${GST_TARGET} PROPERTIES
            INTERFACE_LINK_OPTIONS "${new_ldflags}"
        )
    else()
        set_target_properties(${TARGET} PROPERTIES
            INTERFACE_LINK_OPTIONS "${${PC_STATIC_LDFLAGS_OTHER}}"
        )
    endif()
endmacro()

function(_gst_find_plugin_library _plugin _output_var)
    if(NOT PC_GStreamer_${_plugin}_LIBRARIES)
        set(${_output_var} "" PARENT_SCOPE)
        return()
    endif()
    list(GET PC_GStreamer_${_plugin}_LIBRARIES 0 _lib_name)
    find_library(_gst_${_plugin}_LIBRARY
        NAMES "${_lib_name}"
        PATHS ${PC_GStreamer_${_plugin}_LIBRARY_DIRS}
        NO_DEFAULT_PATH
        NO_CMAKE_FIND_ROOT_PATH
    )
    set(${_output_var} "${_gst_${_plugin}_LIBRARY}" PARENT_SCOPE)
endfunction()

function(_gst_create_imported_dep_targets output_var)
    set(_lib_paths ${ARGN})
    set(_targets)
    foreach(_lib IN LISTS _lib_paths)
        if(TARGET "${_lib}")
            list(APPEND _targets "${_lib}")
            continue()
        endif()
        if (_lib MATCHES "\\.a$")
            message(VERBOSE "  GStreamer dep [skipped .a]:      ${_lib}")
            continue()
        endif()
        # Skip known system libraries (libm, libc, libdl, etc.) — they are
        # already present on the target system and must not be bundled.
        get_filename_component(_lib_basename "${_lib}" NAME)
        string(REGEX REPLACE "^lib" ""    _lib_stem "${_lib_basename}")
        string(REGEX REPLACE "\\.so.*$" "" _lib_stem "${_lib_stem}")
        if (_lib_stem IN_LIST _gst_IGNORED_SYSTEM_LIBRARIES)
            message(VERBOSE "  GStreamer dep [skipped system]:  ${_lib}")
            continue()
        endif()
        if(NOT EXISTS "${_lib}")
            list(APPEND _targets "${_lib}")
            message(VERBOSE "  GStreamer dep [flag/not found]:  ${_lib}")
            continue()
        endif()
        get_filename_component(_lib_name "${_lib}" NAME)
        string(MAKE_C_IDENTIFIER "${_lib_name}" _lib_id)
        set(_target_name "GStreamer::_dep_${_lib_id}")
        if(NOT TARGET "${_target_name}")
            add_library("${_target_name}" UNKNOWN IMPORTED)
            set_target_properties("${_target_name}" PROPERTIES
                IMPORTED_LOCATION "${_lib}"
            )
            # Accumulate into the global dep-target list.
            set_property(GLOBAL APPEND PROPERTY _GStreamer_dep_targets "${_target_name}")
        endif()
        message(VERBOSE "  GStreamer dep [imported]:        ${_target_name} -> ${_lib}")
        list(APPEND _targets "${_target_name}")
    endforeach()
    set(${output_var} "${_targets}" PARENT_SCOPE)
endfunction()

################################
#      Set up the targets      #
################################

find_package(PkgConfig REQUIRED)

# When bundling, append --static to PKG_CONFIG_EXECUTABLE so every
# pkg_check_modules call below includes Requires.private in _LINK_LIBRARIES.
# list(APPEND) shadows the cache variable; unset() at the end of this file
# restores it so the rest of the project is unaffected.
if (GStreamer_BUNDLE_DEPS)
    list(APPEND PKG_CONFIG_EXECUTABLE "--static")
endif()

# GStreamer's pkg-config modules are a MUST -- but we'll test them below
pkg_check_modules(PC_GStreamer gstreamer-1.0 ${GStreamer_EXTRA_DEPS})
# Simulate the list that'll be wholearchive'd.
# Unfortunately, this uses an option only available with pkgconf.
# set(_old_pkg_config_executable "${PKG_CONFIG_EXECUTABLE}")
# set(PKG_CONFIG_EXECUTABLE ${PKG_CONFIG_EXECUTABLE} --maximum-traverse-depth=1)
# pkg_check_modules(PC_GStreamer_NoDeps QUIET REQUIRED gstreamer-1.0 ${GStreamer_EXTRA_DEPS})
# set(PKG_CONFIG_EXECUTABLE "${_old_pkg_config_executable}")

set(GStreamer_VERSION "${PC_GStreamer_VERSION}")

# Test validity of the paths
# NOTE: only paths that must be considered are those provided by pkg-config
# NOTE 2: also exclude sysroots
find_path(GStreamer_INCLUDE_DIR
    NAMES gst/gstversion.h
    PATHS ${PC_GStreamer_INCLUDE_DIRS}
    PATH_SUFFIXES gstreamer-1.0
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH
    REQUIRED
)

find_library(GStreamer_LIBRARY
    NAMES gstreamer-1.0
    PATHS ${PC_GStreamer_LIBRARY_DIRS}
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH
    REQUIRED
)

# Android: Ignore these libraries when constructing the IMPORTED_LOCATION
set(_gst_IGNORED_SYSTEM_LIBRARIES c c++ unwind m dl atomic)
if (ANDROID)
    list(APPEND _gst_IGNORED_SYSTEM_LIBRARIES log GLESv2 EGL OpenSLES android vulkan)
elseif(APPLE)
    list(APPEND _gst_IGNORED_SYSTEM_LIBRARIES iconv resolv System)
endif()

# Normalize library flags coming from srt/haisrt
# https://github.com/Haivision/srt/commit/b90b64d26f850fb0efcc4cdd8b31cbf74bd4db0c
set(_gst_SRT_REGEX_PATCH "^:lib(.+)\\.(a|so|lib|dylib)$")

if(PC_GStreamer_FOUND AND (NOT TARGET GStreamer::GStreamer))
    add_library(GStreamer::GStreamer INTERFACE IMPORTED)

    if (GStreamer_USE_STATIC_LIBS)
        _gst_filter_missing_directories(PC_GStreamer_STATIC_INCLUDE_DIRS)
        set_target_properties(GStreamer::GStreamer PROPERTIES
            INTERFACE_COMPILE_OPTIONS "${PC_GStreamer_STATIC_CFLAGS_OTHER}"
        )
        if (PC_GStreamer_STATIC_INCLUDE_DIRS)
            set_target_properties(GStreamer::GStreamer PROPERTIES
                INTERFACE_INCLUDE_DIRECTORIES "${PC_GStreamer_STATIC_INCLUDE_DIRS}"
            )
        endif()
        _gst_apply_frameworks(PC_GStreamer_STATIC_LDFLAGS_OTHER GStreamer::GStreamer)
    else()
        set_target_properties(GStreamer::GStreamer PROPERTIES
            INTERFACE_COMPILE_OPTIONS "${PC_GStreamer_CFLAGS_OTHER}"
            INTERFACE_INCLUDE_DIRECTORIES "${PC_GStreamer_INCLUDE_DIRS}"
            INTERFACE_LINK_OPTIONS "${PC_GStreamer_LDFLAGS_OTHER}"
        )
    endif()

    add_library(GStreamer::deps INTERFACE IMPORTED)

    if (NOT GStreamer_USE_STATIC_LIBS)
        _gst_dep_libs(_gst_dep_lib_list PC_GStreamer)
        _gst_create_imported_dep_targets(_gst_dep_targets ${_gst_dep_lib_list})
        set_target_properties(GStreamer::deps PROPERTIES
            INTERFACE_LINK_LIBRARIES "${_gst_dep_targets}"
        )
        message(VERBOSE "GStreamer::GStreamer [${GStreamer_LIBRARY}]")
        message(VERBOSE "  GStreamer::deps -> ${_gst_dep_targets}")
        # We're done
    else()
        # Handle all libraries, even those specified with -l:libfoo.a (srt)
        # Due to the unavailability of pkgconf's `--maximum-traverse-depth`
        # on stock pkg-config, I attempt to simulate it through the shared
        # libraries listing.
        # If pkgconf is available, replace all PC_GStreamer_ entries with
        # PC_GStreamer_NoDeps and uncomment the code block above.
        foreach(LOCAL_LIB IN LISTS PC_GStreamer_LIBRARIES)
            # list(TRANSFORM REPLACE) is of no use here
            # https://gitlab.kitware.com/cmake/cmake/-/issues/16899
            if (LOCAL_LIB MATCHES "${_gst_SRT_REGEX_PATCH}")
                string(REGEX REPLACE "${_gst_SRT_REGEX_PATCH}" "\\1" LOCAL_LIB "${LOCAL_LIB}")
            endif()
            string(MAKE_C_IDENTIFIER "_gst_${LOCAL_LIB}" GST_LOCAL_LIB)
            if (NOT ${GST_LOCAL_LIB})
                _gst_find_library(${LOCAL_LIB} ${GST_LOCAL_LIB} ${PC_GStreamer_STATIC_LIBRARY_DIRS})
            endif()
            target_link_libraries(GStreamer::GStreamer INTERFACE
                "${${GST_LOCAL_LIB}}"
            )
        endforeach()

        _gst_apply_link_libraries(ON PC_GStreamer_STATIC_LIBRARIES PC_GStreamer_STATIC_LIBRARY_DIRS GStreamer::deps)
    endif()

    target_link_libraries(GStreamer::GStreamer
        INTERFACE
            GStreamer::deps
    )
endif()

foreach(_gst_PLUGIN IN LISTS GSTREAMER_PLUGINS)
    # Safety valve for the custom targets above
    if ("${_gst_plugin}" IN_LIST _gst_CUSTOM_TARGETS)
        continue()
    endif()

    if (TARGET GStreamer::${_gst_PLUGIN})
        continue()
    endif()

    if (GStreamer_FIND_REQUIRED_${_gst_PLUGIN})
        set(_gst_PLUGIN_REQUIRED REQUIRED)
    else()
        set(_gst_PLUGIN_REQUIRED)
    endif()

    pkg_check_modules(PC_GStreamer_${_gst_PLUGIN} "gst${_gst_PLUGIN}")

    set(GStreamer_${_gst_PLUGIN}_FOUND "${PC_GStreamer_${_gst_PLUGIN}_FOUND}")
    if (NOT GStreamer_${_gst_PLUGIN}_FOUND)
        continue()
    endif()

    _gst_find_plugin_library(${_gst_PLUGIN} _gst_plugin_library)
    if (NOT _gst_plugin_library)
        set(GStreamer_${_gst_PLUGIN}_FOUND FALSE)
        continue()
    endif()

    add_library(GStreamer::${_gst_PLUGIN} UNKNOWN IMPORTED)
    _gst_filter_missing_directories(PC_GStreamer_${_gst_PLUGIN}_INCLUDE_DIRS)
    set_target_properties(GStreamer::${_gst_PLUGIN} PROPERTIES
        IMPORTED_LOCATION "${_gst_plugin_library}"
        INTERFACE_COMPILE_OPTIONS "${PC_GStreamer_${_gst_PLUGIN}_CFLAGS_OTHER}"
    )
    if (PC_GStreamer_${_gst_PLUGIN}_INCLUDE_DIRS)
        set_target_properties(GStreamer::${_gst_PLUGIN} PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${PC_GStreamer_${_gst_PLUGIN}_INCLUDE_DIRS}"
        )
    endif()
    if (GStreamer_USE_STATIC_LIBS)
        _gst_apply_frameworks(PC_GStreamer_${_gst_PLUGIN}_STATIC_LDFLAGS_OTHER GStreamer::${_gst_PLUGIN})
    else()
        _gst_dep_libs(_gst_plugin_deps PC_GStreamer_${_gst_PLUGIN})
        if(_gst_plugin_deps)
            list(REMOVE_AT _gst_plugin_deps 0)
        endif()
        _gst_create_imported_dep_targets(_gst_plugin_dep_targets ${_gst_plugin_deps})
        set_target_properties(GStreamer::${_gst_PLUGIN} PROPERTIES
            INTERFACE_LINK_OPTIONS "${PC_GStreamer_${_gst_PLUGIN}_LDFLAGS_OTHER}"
            INTERFACE_LINK_LIBRARIES "${_gst_plugin_dep_targets}"
        )
        message(VERBOSE "GStreamer::${_gst_PLUGIN} [${_gst_plugin_library}]")
        message(VERBOSE "  deps -> ${_gst_plugin_dep_targets}")
        continue()
    endif()

    _gst_apply_link_libraries(OFF PC_GStreamer_${_gst_PLUGIN}_STATIC_LIBRARIES PC_GStreamer_${_gst_PLUGIN}_STATIC_LIBRARY_DIRS GStreamer::${_gst_PLUGIN})
endforeach()

foreach(_gst_PLUGIN IN LISTS GSTREAMER_APIS)
    # Safety valve for the custom targets above
    if ("${_gst_plugin}" IN_LIST _gst_CUSTOM_TARGETS)
        continue()
    endif()

    if (TARGET GStreamer::${_gst_PLUGIN})
        continue()
    endif()

    if (GStreamer_FIND_REQUIRED_${_gst_PLUGIN})
        set(_gst_PLUGIN_REQUIRED REQUIRED)
    else()
        set(_gst_PLUGIN_REQUIRED)
    endif()

    string(REGEX REPLACE "^api_(.+)" "\\1" _gst_PLUGIN_PC "${_gst_PLUGIN}")
    string(REPLACE "_" "-" _gst_PLUGIN_PC "${_gst_PLUGIN_PC}")

    pkg_check_modules(PC_GStreamer_${_gst_PLUGIN} "gstreamer-${_gst_PLUGIN_PC}-1.0")

    set(GStreamer_${_gst_PLUGIN}_FOUND "${PC_GStreamer_${_gst_PLUGIN}_FOUND}")
    if (NOT GStreamer_${_gst_PLUGIN}_FOUND)
        continue()
    endif()

    _gst_find_plugin_library(${_gst_PLUGIN} _gst_plugin_library)
    if (NOT _gst_plugin_library)
        set(GStreamer_${_gst_PLUGIN}_FOUND FALSE)
        continue()
    endif()

    add_library(GStreamer::${_gst_PLUGIN} UNKNOWN IMPORTED)
    _gst_filter_missing_directories(PC_GStreamer_${_gst_PLUGIN}_INCLUDE_DIRS)
    set_target_properties(GStreamer::${_gst_PLUGIN} PROPERTIES
        IMPORTED_LOCATION "${_gst_plugin_library}"
        INTERFACE_COMPILE_OPTIONS "${PC_GStreamer_${_gst_PLUGIN}_CFLAGS_OTHER}"
        INTERFACE_LINK_OPTIONS "${PC_GStreamer_${_gst_PLUGIN}_LDFLAGS_OTHER}"
    )
    if (PC_GStreamer_${_gst_PLUGIN}_INCLUDE_DIRS)
        set_target_properties(GStreamer::${_gst_PLUGIN} PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${PC_GStreamer_${_gst_PLUGIN}_INCLUDE_DIRS}"
        )
    endif()
    if (GStreamer_USE_STATIC_LIBS)
        _gst_apply_frameworks(PC_GStreamer_${_gst_PLUGIN}_STATIC_LDFLAGS_OTHER GStreamer::${_gst_PLUGIN})
    else()
        _gst_dep_libs(_gst_plugin_deps PC_GStreamer_${_gst_PLUGIN})
        if(_gst_plugin_deps)
            list(REMOVE_AT _gst_plugin_deps 0)
        endif()
        _gst_create_imported_dep_targets(_gst_plugin_dep_targets ${_gst_plugin_deps})
        set_target_properties(GStreamer::${_gst_PLUGIN} PROPERTIES
            INTERFACE_LINK_OPTIONS "${PC_GStreamer_${_gst_PLUGIN}_LDFLAGS_OTHER}"
            INTERFACE_LINK_LIBRARIES "${_gst_plugin_dep_targets}"
        )
        message(VERBOSE "GStreamer::${_gst_PLUGIN} [${_gst_plugin_library}]")
        message(VERBOSE "  deps -> ${_gst_plugin_dep_targets}")
        continue()
    endif()

    _gst_apply_link_libraries(OFF PC_GStreamer_${_gst_PLUGIN}_STATIC_LIBRARIES PC_GStreamer_${_gst_PLUGIN}_STATIC_LIBRARY_DIRS GStreamer::${_gst_PLUGIN})
endforeach()

# Perform final validation
include(FindPackageHandleStandardArgs)
set(_gst_handle_version_range)
if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.19.0")
    set(_gst_handle_version_range "HANDLE_VERSION_RANGE")
endif()
find_package_handle_standard_args(GStreamer
    REQUIRED_VARS
        GStreamer_LIBRARY
        GStreamer_INCLUDE_DIR
    VERSION_VAR GStreamer_VERSION
    ${_gst_handle_version_range}
    HANDLE_COMPONENTS
)

# Create MODULE IMPORTED targets for every runtime plugin .so in lib/gstreamer-1.0/.
# GStreamer loads these via dlopen() at gst_init() time — they are not linked.
# MODULE type (not UNKNOWN) is required for install(IMPORTED_RUNTIME_ARTIFACTS).
set(GStreamer_PLUGIN_TARGETS "")
file(GLOB _gst_plugin_files "${GStreamer_ROOT_DIR}/lib/gstreamer-1.0/libgst*.so")
foreach(_gst_plugin_file IN LISTS _gst_plugin_files)
    get_filename_component(_gst_plugin_fname "${_gst_plugin_file}" NAME)
    string(MAKE_C_IDENTIFIER "${_gst_plugin_fname}" _gst_plugin_id)
    set(_gst_plugin_target "GStreamer::_plugin_${_gst_plugin_id}")
    if(NOT TARGET "${_gst_plugin_target}")
        add_library("${_gst_plugin_target}" MODULE IMPORTED)
        set_target_properties("${_gst_plugin_target}" PROPERTIES
            IMPORTED_LOCATION "${_gst_plugin_file}"
        )
    endif()
    list(APPEND GStreamer_PLUGIN_TARGETS "${_gst_plugin_target}")
endforeach()
unset(_gst_plugin_files)
unset(_gst_plugin_file)
unset(_gst_plugin_fname)
unset(_gst_plugin_id)
unset(_gst_plugin_target)

# For each plugin listed in GSTREAMER_RUNTIME_PLUGINS, read its DT_NEEDED entries
# via readelf at configure time and register the resolved SDK libraries as
# GStreamer::_dep_* IMPORTED targets appended to GStreamer::GStreamer.
if(GSTREAMER_RUNTIME_PLUGINS)
    set(_gst_sdk_lib_dirs
        "${GStreamer_ROOT_DIR}/lib"
        "${GStreamer_ROOT_DIR}/lib/x86_64-linux-gnu"
    )
    set(_gst_rplugin_all_dep_targets "")

    foreach(_gst_rplugin IN LISTS GSTREAMER_RUNTIME_PLUGINS)
        set(_gst_rplugin_file "${GStreamer_ROOT_DIR}/lib/gstreamer-1.0/libgst${_gst_rplugin}.so")
        if(NOT EXISTS "${_gst_rplugin_file}")
            message(WARNING "GStreamer: runtime plugin '${_gst_rplugin}' not found at ${_gst_rplugin_file}")
            continue()
        endif()

        execute_process(
            COMMAND readelf -d "${_gst_rplugin_file}"
            OUTPUT_VARIABLE _gst_readelf_out
            ERROR_QUIET
        )

        string(REGEX MATCHALL "Shared library: \\[[^\]]+\\]" _gst_needed_entries "${_gst_readelf_out}")

        set(_gst_rplugin_dep_paths "")
        foreach(_gst_needed IN LISTS _gst_needed_entries)
            string(REGEX REPLACE "Shared library: \\[([^\]]+)\\]" "\\1" _gst_libname "${_gst_needed}")
            foreach(_gst_libdir IN LISTS _gst_sdk_lib_dirs)
                if(EXISTS "${_gst_libdir}/${_gst_libname}")
                    list(APPEND _gst_rplugin_dep_paths "${_gst_libdir}/${_gst_libname}")
                    break()
                endif()
            endforeach()
        endforeach()

        _gst_create_imported_dep_targets(_gst_rplugin_dep_targets ${_gst_rplugin_dep_paths})
        list(APPEND _gst_rplugin_all_dep_targets ${_gst_rplugin_dep_targets})
        message(VERBOSE "GStreamer runtime plugin [${_gst_rplugin}] deps -> ${_gst_rplugin_dep_targets}")
    endforeach()

    if(_gst_rplugin_all_dep_targets)
        list(REMOVE_DUPLICATES _gst_rplugin_all_dep_targets)
        set_property(TARGET GStreamer::GStreamer APPEND PROPERTY
            INTERFACE_LINK_LIBRARIES "${_gst_rplugin_all_dep_targets}"
        )
    endif()

    unset(_gst_sdk_lib_dirs)
    unset(_gst_rplugin)
    unset(_gst_rplugin_file)
    unset(_gst_readelf_out)
    unset(_gst_needed_entries)
    unset(_gst_needed)
    unset(_gst_libname)
    unset(_gst_libdir)
    unset(_gst_rplugin_dep_paths)
    unset(_gst_rplugin_dep_targets)
    unset(_gst_rplugin_all_dep_targets)
endif()

# Expose all GStreamer::_dep_* IMPORTED targets created during this run,
# including any plugin dependency targets added by GSTREAMER_RUNTIME_PLUGINS.
get_property(GStreamer_BUNDLED_TARGETS GLOBAL PROPERTY _GStreamer_dep_targets)

# Restore PKG_CONFIG_EXECUTABLE to the cache value (removes the --static shadow)
if (GStreamer_BUNDLE_DEPS)
    unset(PKG_CONFIG_EXECUTABLE)
endif()
