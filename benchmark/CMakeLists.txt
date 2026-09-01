find_package(benchmark REQUIRED)

add_executable(devkit_benchmarks
    circle_benchmark.cpp
    rectangle_benchmark.cpp
)

target_link_libraries(devkit_benchmarks
    PRIVATE
        devkit::shapes
        benchmark::benchmark
        benchmark::benchmark_main
)

# conflicto de -fPIC -fPIE por eso no reusamos
#target_precompile_headers(devkit_benchmarks REUSE_FROM devkit_shapes)
target_precompile_headers(devkit_benchmarks
    PRIVATE
        <benchmark/benchmark.h>
        <string>
)

devkit_configure_target(devkit_benchmarks)

set_target_properties(devkit_benchmarks PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY               "${PROJECT_SOURCE_DIR}/bin/benchmark"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG         "${PROJECT_SOURCE_DIR}/bin/benchmark"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE       "${PROJECT_SOURCE_DIR}/bin/benchmark"
    RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${PROJECT_SOURCE_DIR}/bin/benchmark"
)
