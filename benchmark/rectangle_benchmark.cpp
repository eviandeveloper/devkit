#include <benchmark/benchmark.h>

#include "devkit/rectangle.hpp"

namespace {

void BM_RectangleConstruction(benchmark::State& state) {  // NOLINT(readability-identifier-length)
    for (auto _ : state) {                                // NOLINT(readability-identifier-length)
        devkit::Rectangle rectangle(3.0, 4.0);
        benchmark::DoNotOptimize(rectangle);
    }
}
BENCHMARK(BM_RectangleConstruction);

void BM_RectangleArea(benchmark::State& state) {  // NOLINT(readability-identifier-length)
    const devkit::Rectangle kRectangle(3.0, 4.0);
    for (auto _ : state) {  // NOLINT(readability-identifier-length)
        benchmark::DoNotOptimize(kRectangle.Area());
    }
}
BENCHMARK(BM_RectangleArea);

}  // namespace

// BENCHMARK_MAIN();
