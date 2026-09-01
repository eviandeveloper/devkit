# ==============================================================================
# Hardening.cmake
# Flags de mitigación de exploits, aplicados SOLO en Release. En Debug ya
# tenemos ASan/UBSan (más precisos para detectar estos bugs); combinarlos con
# hardening es redundante y -D_FORTIFY_SOURCE requiere optimización (-O1+),
# incompatible con -Og en algunos casos.
# ==============================================================================

option(DEVKIT_ENABLE_HARDENING "Aplicar flags de mitigación de exploits en Release" ON)

function(devkit_enable_hardening target_name)
    if(NOT DEVKIT_ENABLE_HARDENING)
        return()
    endif()

    get_target_property(target_type ${target_name} TYPE)
    set(is_release "$<CONFIG:Release>")

    if(MSVC)
        target_compile_options(${target_name} PRIVATE
            "$<${is_release}:/GS;/guard:cf>"
        )
        target_link_options(${target_name} PRIVATE
            "$<${is_release}:/DYNAMICBASE;/NXCOMPAT>"
        )
    else()
        target_compile_options(${target_name} PRIVATE
            "$<${is_release}:-fstack-protector-strong;-D_FORTIFY_SOURCE=2>"
        )
        if(target_type STREQUAL "EXECUTABLE")
            target_compile_options(${target_name} PRIVATE "$<${is_release}:-fPIE>")
            target_link_options(${target_name} PRIVATE "$<${is_release}:-pie>")
        endif()
        target_link_options(${target_name} PRIVATE "$<${is_release}:-Wl,-z,relro,-z,now>")
    endif()
endfunction()
