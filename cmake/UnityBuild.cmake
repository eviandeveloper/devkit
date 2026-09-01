# ==============================================================================
# UnityBuild.cmake
# Unity build opcional (agrupa varios .cpp en menos unidades de compilación
# para acelerar el build limpio). Desactivado por defecto: puede esconder
# bugs de ODR/colisión de `static`/macros entre ficheros distintos.
# ==============================================================================

option(DEVKIT_ENABLE_UNITY_BUILD "Agrupar .cpp en unity builds (compilación más rápida, mayor riesgo de colisiones ODR)" OFF)

function(devkit_enable_unity_build target_name)
    if(NOT DEVKIT_ENABLE_UNITY_BUILD)
        return()
    endif()

    set_target_properties(${target_name} PROPERTIES
        UNITY_BUILD ON
        UNITY_BUILD_BATCH_SIZE 8
    )
endfunction()
