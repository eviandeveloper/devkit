# ==============================================================================
# StaticAnalyzers.cmake
# clang-tidy e IWYU aplicados por target (vía CXX_CLANG_TIDY/CXX_INCLUDE_WHAT_YOU_USE).
# cppcheck se registra como target independiente `cppcheck` (ver Cppcheck.cmake),
# ya que --project es incompatible con la invocación por-fichero de CXX_CPPCHECK.
# Todos analizan EXCLUSIVAMENTE nuestro propio código, nunca dependencias de Conan.
# ==============================================================================

option(ENABLE_CLANG_TIDY "Habilitar análisis con clang-tidy" OFF)
option(ENABLE_IWYU "Habilitar análisis con include-what-you-use" OFF)

function(devkit_enable_static_analysis target_name)
    if(ENABLE_CLANG_TIDY)
        find_program(CLANGTIDY clang-tidy)
        if(CLANGTIDY)
            set_target_properties(${target_name} PROPERTIES
                # Wno-ignored-gch para si el PCH se compilo con GCC y despues se usa Clang
                CXX_CLANG_TIDY "${CLANGTIDY};--extra-arg=-Wno-unknown-warning-option;--extra-arg=-Wno-ignored-gch"
            )
        else()
            message(WARNING "clang-tidy solicitado pero no encontrado")
        endif()
    endif()

    if(ENABLE_IWYU)
        find_program(IWYU include-what-you-use)
        if(IWYU)
            set_target_properties(${target_name} PROPERTIES
                CXX_INCLUDE_WHAT_YOU_USE "${IWYU};-Xiwyu;--mapping_file=${PROJECT_SOURCE_DIR}/cmake/iwyu.imp;-Xiwyu;--no_comments;-Wno-unknown-warning-option;--extra-arg=-Wno-ignored-gch"
            )
        else()
            message(WARNING "include-what-you-use solicitado pero no encontrado")
        endif()
    endif()
endfunction()


# ==============================================================================
# Target independiente `clang-tidy-fix`: aplica automáticamente los fixes que
# clang-tidy sabe generar (modernize-*, etc.) sobre inc/ y src/. Modifica los
# ficheros in-place — ejecutar SIEMPRE con el repo limpio y revisar el diff
# resultante antes de comittear, nunca aceptar a ciegas.
# ==============================================================================
function(devkit_register_clang_tidy_fix_target)
    if(NOT ENABLE_CLANG_TIDY)
        return()
    endif()

    find_program(CLANGTIDY clang-tidy)
    if(NOT CLANGTIDY)
        return()
    endif()

    file(GLOB_RECURSE DEVKIT_FIX_SOURCES
        ${PROJECT_SOURCE_DIR}/src/*.cpp
        ${PROJECT_SOURCE_DIR}/inc/*.hpp
    )

    add_custom_target(clang-tidy-fix
        COMMAND ${CLANGTIDY}
                -p ${CMAKE_BINARY_DIR}
                --fix --fix-errors
                --extra-arg=-Wno-unknown-warning-option
                --extra-arg=-Wno-ignored-gch
                ${DEVKIT_FIX_SOURCES}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMENT "Aplicando fixes automáticos de clang-tidy sobre inc/ y src/"
        VERBATIM
    )
endfunction()

devkit_register_clang_tidy_fix_target()
