# BA Find GStreamer

A CMake find module for GStreamer (`FindGStreamer.cmake`) that exports GStreamer
plugins and APIs as proper CMake imported targets, designed for use with custom
or bundled GStreamer SDK installations.

## Differences from the upstream finder

Based on the upstream `FindGStreamer.cmake` from the GStreamer repository. The following
features are added on top:

- Plugin and API targets are `UNKNOWN IMPORTED` with `IMPORTED_LOCATION` instead of
  `INTERFACE IMPORTED`, enabling `install(IMPORTED_RUNTIME_ARTIFACTS)` on them directly
- `GStreamer_BUNDLE_DEPS` — includes `Requires.private` dependencies in the imported
  target graph for full SDK bundling
- `GStreamer_BUNDLED_TARGETS` — list of all `GStreamer::_dep_*` transitive dependency
  targets created during `find_package`, ready for `install(IMPORTED_RUNTIME_ARTIFACTS)`
- `GSTREAMER_RUNTIME_PLUGINS` — resolves `DT_NEEDED` deps of runtime plugins at
  configure time and registers them as `GStreamer::_dep_*` targets
- `GStreamer_PLUGIN_TARGETS` — `MODULE IMPORTED` targets for every
  `lib/gstreamer-1.0/libgst*.so` in the SDK, ready for `install(IMPORTED_RUNTIME_ARTIFACTS)`

The original `FindGStreamer.cmake` is from Gstreamer repository with tag [1.28.1](https://gitlab.freedesktop.org/gstreamer/gstreamer/-/blob/1.28.1/subprojects/gstreamer/cmake/FindGStreamer.cmake?ref_type=tags) and the
differences are in `diff/FindGStreamer.diff`.

## Installation

Clone the repository to a stable location:

```bash
git clone https://github.com/bacpack-system/ba-find-gstreamer ~/ba-find-gstreamer
```

Add `GStreamer_DIR` to your shell environment (e.g. `~/.bashrc`):

```bash
export GStreamer_DIR=~/ba-find-gstreamer
```

## Usage

In any CMake project:

```cmake
find_package(GStreamer REQUIRED)
```

CMake uses `GStreamer_DIR` to locate `GStreamerConfig.cmake` in this repository,
which runs the full finder.

### Finding plugins and APIs

Pass plugins via `GSTREAMER_PLUGINS` and APIs via `GSTREAMER_APIS` before the
`find_package` call:

```cmake
set(GSTREAMER_PLUGINS app rtp rtsp)
set(GSTREAMER_APIS api_app api_rtp)
find_package(GStreamer REQUIRED)

target_link_libraries(my_target PRIVATE
    GStreamer::GStreamer
    GStreamer::app
    GStreamer::api_app
)
```

### Fixing pkg-config prefixes in a custom SDK

If the GStreamer SDK was built with a fixed install prefix (e.g. `/INSTALL`) that
differs from where it is actually located at build time, use `BA_FIX_PKGCONFIG` to
rewrite all `.pc` files in place before calling `find_package`:

```cmake
BA_FIX_PKGCONFIG(${GSTREAMER_DIR})
find_package(GStreamer REQUIRED)
```

This replaces every occurrence of `/INSTALL` in `.pc` files under `GSTREAMER_DIR`
with the `GSTREAMER_DIR` path, so `pkg-config` returns correct include and library paths.

### Custom SDK installation

Point `GStreamer_ROOT_DIR` to your GStreamer SDK prefix:

```cmake
set(GStreamer_ROOT_DIR /path/to/gstreamer-sdk)
find_package(GStreamer REQUIRED)
```

### Bundling the GStreamer SDK alongside the application

Set `GStreamer_BUNDLE_DEPS` to include `Requires.private` dependencies in the
imported target graph. After `find_package`, use `GStreamer_BUNDLED_TARGETS` to
install all transitive shared libraries:

```cmake
set(GStreamer_BUNDLE_DEPS ON)
find_package(GStreamer REQUIRED)

install(IMPORTED_RUNTIME_ARTIFACTS
    GStreamer::GStreamer
    GStreamer::api_app
    GStreamer::api_video
    ${GStreamer_BUNDLED_TARGETS}
    LIBRARY DESTINATION lib
)
```

`GStreamer_BUNDLED_TARGETS` contains all `GStreamer::_dep_*` IMPORTED targets
created during `find_package`, including transitive deps of any `GSTREAMER_PLUGINS`,
`GSTREAMER_APIS`, and `GSTREAMER_RUNTIME_PLUGINS` entries.

### Installing runtime plugins

GStreamer loads plugins from `lib/gstreamer-1.0/` via `dlopen()` at `gst_init()`
time — they are never linked. `GStreamer_PLUGIN_TARGETS` contains MODULE IMPORTED
targets for every `libgst*.so` found in `${GStreamer_ROOT_DIR}/lib/gstreamer-1.0/`.

Use `BA_INSTALL_AND_PATCHELF_GSTREAMER_PLUGINS` (provided by `Tools.cmake`) to
install all plugins to the given destination and fix their RUNPATH in one call:

```cmake
BA_INSTALL_AND_PATCHELF_GSTREAMER_PLUGINS(DESTINATION lib/gstreamer-1.0)
```

This installs every target from `GStreamer_PLUGIN_TARGETS` to `lib/gstreamer-1.0/`
and runs `patchelf --set-rpath $ORIGIN/..` on each `.so` so plugins can find their
dependencies in the adjacent `lib/` directory.

### Resolving runtime plugin dependencies

To ensure the shared libraries required by specific runtime plugins are also
installed to `lib/`, list the plugin names in `GSTREAMER_RUNTIME_PLUGINS` before
`find_package`. The finder reads each plugin's `DT_NEEDED` entries via `readelf`
at configure time and registers the resolved libraries as `GStreamer::_dep_*`
targets, which are appended to `GStreamer_BUNDLED_TARGETS`:

```cmake
set(GSTREAMER_RUNTIME_PLUGINS app coreelements dtls rtp rtpmanager rtsp udp videoconvertscale videofilter videotestsrc x264 x265)
set(GStreamer_BUNDLE_DEPS ON)
find_package(GStreamer REQUIRED)

install(IMPORTED_RUNTIME_ARTIFACTS ${GStreamer_BUNDLED_TARGETS}
    LIBRARY DESTINATION lib
)
BA_INSTALL_AND_PATCHELF_GSTREAMER_PLUGINS(DESTINATION lib/gstreamer-1.0)
```
