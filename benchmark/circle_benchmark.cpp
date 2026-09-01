#include <benchmark/benchmark.h>

#include "devkit/circle.hpp"

namespace {

void BM_CircleConstruction(benchmark::State& state) {  // NOLINT(readability-identifier-length)
    for (auto _ : state) {                             // NOLINT(readability-identifier-length)
        devkit::Circle circle(2.0);
        benchmark::DoNotOptimize(circle);
    }
}
BENCHMARK(BM_CircleConstruction);

void BM_CircleArea(benchmark::State& state) {  // NOLINT(readability-identifier-length)
    const devkit::Circle kCircle(2.0);         // NOLINT(readability-identifier-length)
    for (auto _ : state) {
        benchmark::DoNotOptimize(kCircle.Area());
    }
}
BENCHMARK(BM_CircleArea);

}  // namespace
