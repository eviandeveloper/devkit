# ==============================================================================
# Devkit.cmake
# Punto único para aplicar toda la configuración estándar a un target propio.
# ==============================================================================

function(devkit_configure_target target_name)
    devkit_set_project_warnings(${target_name})
    devkit_set_debug_info(${target_name})
    devkit_enable_sanitizers(${target_name})
    devkit_set_release_optimizations(${target_name})
    devkit_enable_static_analysis(${target_name})
    devkit_enable_coverage(${target_name})
    devkit_enable_hardening(${target_name})
    devkit_enable_unity_build(${target_name})
endfunction()