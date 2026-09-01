include(CMakeFindDependencyMacro)
# Solo busca fmt si no ha sido traído ya por otro sitio (como Conan o FetchContent)
if(NOT TARGET fmt::fmt)
    find_dependency(fmt)
endif()
include("${CMAKE_CURRENT_LIST_DIR}/devkitTargets.cmake")

# Crear el alias para que el usuario pueda usar devkit::shapes
if(TARGET devkit::devkit_shapes AND NOT TARGET devkit::shapes)
    add_library(devkit::shapes INTERFACE IMPORTED)
    target_link_libraries(devkit::shapes INTERFACE devkit::devkit_shapes)
endif()

# Lo mismo para el main
if(TARGET devkit::devkit_shapes_main AND NOT TARGET devkit::shapes_main)
    add_library(devkit::shapes_main INTERFACE IMPORTED)
    target_link_libraries(devkit::shapes_main INTERFACE devkit::devkit_shapes_main)
endif()
