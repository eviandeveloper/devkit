cmake_minimum_required(VERSION 3.25)

project(devkit
    VERSION 0.7.3
    DESCRIPTION "Plantilla profesional de proyecto C++"
    LANGUAGES CXX
)

# Detecta si devkit es el proyecto top-level o está embebido via FetchContent/add_subdirectory
if(CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
    set(DEVKIT_IS_TOP_LEVEL ON)
else()
    set(DEVKIT_IS_TOP_LEVEL OFF)
endif()

# Como top-level, SIEMPRE forzamos nuestro estándar (incluso si el toolchain de
# Conan ya definió uno, p. ej. compiler.cppstd=gnu17). Como dependencia embebida
# (FetchContent), respetamos el estándar que ya haya fijado el proyecto padre.
if(DEVKIT_IS_TOP_LEVEL OR NOT DEFINED CMAKE_CXX_STANDARD)
    set(CMAKE_CXX_STANDARD 20)
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

include(StandardProjectSettings)
include(ccache)
include(CompilerWarnings)
include(Sanitizers)
include(DebugInfo)
include(StaticAnalyzers)
include(Cppcheck)
include(Optimizations)
include(Coverage)
include(Documentation)
include(Valgrind)
include(Fuzzing)
include(Hardening)
include(UnityBuild)
include(Devkit)
include(Version)


# ==============================================================================
# En caso de querer añadir hilos basta con descomentar find_package(Threads REQUIRED)
# y añadirlo al target_link_libraries de cada subproyecto
# por ejemplo el comentando en src/CMAKELists.txt
# recuerda que si lo pones como PUBLIC los proyectos que dependan de ese subproyecto
# heredan hilos
# ==============================================================================
#find_package(Threads REQUIRED)

# ==============================================================================
# fmt: si el target ya existe (traído por Conan, o por el consumidor vía su
# propio FetchContent/add_subdirectory antes de embebernos), lo reutilizamos.
# Si no existe (p. ej. alguien nos consume con FetchContent "a pelo", sin
# Conan), lo traemos nosotros mismos — devkit es responsable de su propia
# dependencia, el consumidor no debería tener que saber que la usamos.
# ==============================================================================
if(NOT TARGET fmt::fmt)
    find_package(fmt QUIET)
endif()

if(NOT TARGET fmt::fmt)
    include(FetchContent)
    FetchContent_Declare(
        fmt
        GIT_REPOSITORY https://github.com/fmtlib/fmt.git
        GIT_TAG        11.0.2
    )
    FetchContent_MakeAvailable(fmt)
endif()

# Directorios de salida homogéneos para todas las configuraciones
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG          "${PROJECT_SOURCE_DIR}/bin/debug")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE        "${PROJECT_SOURCE_DIR}/bin/release")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${PROJECT_SOURCE_DIR}/bin/release")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY                "${PROJECT_SOURCE_DIR}/bin/debug")

# Detecta si devkit es el proyecto top-level o está embebido via FetchContent/add_subdirectory
if(CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
    set(DEVKIT_IS_TOP_LEVEL ON)
else()
    set(DEVKIT_IS_TOP_LEVEL OFF)
endif()

option(DEVKIT_BUILD_TESTS "Compilar los tests" ${DEVKIT_IS_TOP_LEVEL})
option(DEVKIT_BUILD_APP "Compilar el ejecutable devkit_app" ${DEVKIT_IS_TOP_LEVEL})
option(DEVKIT_BUILD_BENCHMARKS "Compilar los benchmarks" OFF)
option(DEVKIT_BUILD_FUZZERS "Compilar los fuzz targets (requiere Clang)" OFF)
option(DEVKIT_BUILD_INJECTION_TEST "Compilar test de inyección de main" OFF)

add_subdirectory(src)

if(DEVKIT_BUILD_APP)
    add_subdirectory(app)
endif()

if(DEVKIT_BUILD_TESTS)
    enable_testing()
    add_subdirectory(test)
endif()

if(DEVKIT_BUILD_BENCHMARKS)
    add_subdirectory(benchmark)
endif()

if(DEVKIT_BUILD_FUZZERS)
    add_subdirectory(fuzz)
endif()

if(DEVKIT_BUILD_INJECTION_TEST)
    add_subdirectory(main_injection)
endif()

devkit_register_coverage_target()
devkit_register_valgrind_target()
devkit_register_cppcheck_target()


# ==============================================================================
# Instalación / exportación — permite `cmake --install` y que Conan empaquete
# la librería, exponiendo el target devkit::shapes a quien la consuma.
# ==============================================================================
include(GNUInstallDirs)

install(TARGETS devkit_shapes devkit_shapes_main
    EXPORT devkitTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(DIRECTORY ${PROJECT_SOURCE_DIR}/inc/
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/src/generated/inc/devkit/export.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/devkit
)

install(EXPORT devkitTargets
    FILE devkitTargets.cmake
    NAMESPACE devkit::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/devkit
)

include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/devkitConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(FILES
    ${PROJECT_SOURCE_DIR}/cmake/devkitConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/devkitConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/devkit
)


# CPack
if(DEVKIT_IS_TOP_LEVEL)
    # 1. Identificar librerías del sistema (runtimes del compilador)
    include(InstallRequiredSystemLibraries)

    set(CPACK_PACKAGE_NAME "devkit")
    set(CPACK_PACKAGE_VENDOR "Tu Nombre o Empresa")
    set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Librería profesional de formas geométricas")
    set(CPACK_PACKAGE_CONTACT "tu@email.com")
    set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_SOURCE_DIR}/LICENSE")

    # Formatos: Tarball (genérico), DEB (Debian/Ubuntu/Docker), RPM (Fedora)
    set(CPACK_GENERATOR "TGZ;DEB;RPM")

    # --- Configuración específica para DEB ---
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_CONTACT}")

    # Comprobación de seguridad para el archivo de licencia
    if(EXISTS "${PROJECT_SOURCE_DIR}/LICENSE")
        set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_SOURCE_DIR}/LICENSE")
    endif()

    # Intentar detectar la arquitectura (amd64 habitualmente)
    if(NOT CPACK_DEBIAN_PACKAGE_ARCHITECTURE)
        set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
    endif()

    # IMPORTANTE: Autodetecta dependencias de librerías del sistema (libc, libstdc++, etc.)
    # Requiere que dpkg-shlibdeps esté instalado en el sistema
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)

    # Elimina símbolos de debug de los binarios instalados para reducir tamaño
    set(CPACK_STRIP_FILES ON)

    # Organiza el paquete en la carpeta del build, no en la raíz del proyecto
    set(CPACK_PACKAGE_DIRECTORY "${PROJECT_BINARY_DIR}/packages")

    include(CPack)
endif()
