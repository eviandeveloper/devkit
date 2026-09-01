add_library(devkit_shapes
    circle.cpp
    rectangle.cpp
    shape_printer.cpp
)

add_library(devkit::shapes ALIAS devkit_shapes)

# por separado para evitar simbolos duplicados en el linker y que un tercer usuario pueda utilizar el main que quiera
add_library(devkit_shapes_main STATIC devkit_main.cpp)
add_library(devkit::shapes_main ALIAS devkit_shapes_main)
target_link_libraries(devkit_shapes_main PUBLIC devkit_shapes)

# ==============================================================================
# Genera inc/devkit/export.h automáticamente, con el macro DEVKIT_API que
# expande a visibility("default")/dllexport/dllimport según cómo se compile
# y consuma la librería (estática, compartida propia, o compartida externa).
# Necesario porque CMAKE_CXX_VISIBILITY_PRESET=hidden oculta todo por defecto.
# ==============================================================================
include(GenerateExportHeader)
generate_export_header(devkit_shapes
    BASE_NAME devkit
    EXPORT_MACRO_NAME DEVKIT_API
    EXPORT_FILE_NAME ${CMAKE_CURRENT_BINARY_DIR}/generated/inc/devkit/export.h
)


target_include_directories(devkit_shapes
    PUBLIC
        $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/inc>
        $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/generated/inc>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/generated/inc>
        $<INSTALL_INTERFACE:inc>
)

target_link_libraries(devkit_shapes
    PUBLIC # publico al dejar que benchmark y test usen PCH de devkit_shapes
        fmt::fmt
        #Threads::Threads
)

# Aplica warnings, sanitizers, optimizaciones y análisis estático
# SOLO a estos target (nuestro código), nunca a fmt ni a gtest.
devkit_configure_target(devkit_shapes)
devkit_configure_target(devkit_shapes_main)

# PCH para realizar una compilación más rapida, recomendado que sea PRIVATE
target_precompile_headers(devkit_shapes
    PRIVATE
        <string>
        <memory>
        <fmt/format.h>
)
