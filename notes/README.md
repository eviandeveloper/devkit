# devkit

Plantilla profesional de proyecto C++ con Docker, CMake + Presets, Conan, sanitizers, análisis estático, coverage, documentación automática y CI.

---

## 1. Requisitos previos

Solo necesitas tener instalado en tu máquina (host):

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2, integrado en `docker` en instalaciones recientes)

No necesitas instalar CMake, Conan, GCC, Clang, ni ninguna otra herramienta de desarrollo en tu máquina — todo vive dentro del contenedor Docker, garantizando que el entorno sea idéntico para cualquier persona que clone el repositorio.

---

## 2. Primeros pasos (desde cero)

### 2.1. Construir la imagen y levantar el contenedor

```bash
docker-compose -f docker/docker-compose.yml build
docker-compose -f docker/docker-compose.yml up -d
docker-compose -f docker/docker-compose.yml exec dev-env bash
```

A partir de aquí, **todos los comandos de este README se ejecutan dentro del contenedor** (verás el prompt `[dev@... project]$`), salvo que se indique explícitamente "desde el host".

### Configurar git dentro del contenedor

git config --global user.email "tu@email.com"
git config --global user.name "Tu Nombre"

Tambien en docker/docker-compose.yml se añade el volumen ${HOME}/.ssh:/home/dev/.ssh:ro para poder realizar push.

Si lo consideras invasivo recuerda que puedes eliminarlo.

Necesario para pre-commits o realizar push

### 2.2. Compilar y probar por primera vez

```bash
./scripts/configure.sh debug
cmake --build --preset debug
ctest --preset debug --output-on-failure
```

Si los tests pasan, el entorno está listo.

### 2.3. Ejecutar el binario de la aplicación

```bash
./bin/debug/devkit
```

### 2.4. Salir / volver a entrar más tarde

```bash
exit                                                            # el contenedor sigue corriendo en segundo plano
docker-compose -f docker/docker-compose.yml exec dev-env bash   # vuelve a entrar
docker-compose -f docker/docker-compose.yml down                # detiene y elimina el contenedor (los volúmenes ccache/conan persisten)
```

---

## 3. Estructura del proyecto

```
devkit/
├── docker/          # Dockerfile, docker-compose.yml, requirements.txt, .env
├── cmake/           # Módulos CMake (warnings, sanitizers, optimizaciones, análisis estático...)
├── conan/           # Perfiles y settings_user.yml de Conan
├── inc/devkit/       # Headers (.hpp) públicos de la librería
├── src/             # Implementación (.cpp) de la librería devkit_shapes
├── app/             # Driver ejecutable (main.cpp), consume la librería
├── test/            # Tests (GoogleTest + GoogleMock)
├── benchmark/       # Microbenchmarks (Google Benchmark), bajo demanda
├── fuzz/            # Fuzz targets (libFuzzer, solo Clang), bajo demanda
├── test_package/    # Validación del paquete Conan (conan create)
├── main_injection/  # Ejemplo usando el main() proporcionado por la libreria
├── version/          # Template version.h.in
├── docs/            # Salida de Doxygen (generado, no versionado)
├── coverage/        # Salida de gcovr (generado, no versionado)
├── bin/             # Binarios (debug/, release/, test/, benchmark/) (generado, no versionado)
├── temp/            # Artefactos de build (generado, no versionado)
├── scripts/         # Scripts auxiliares (configure.sh, release.sh)
├── .github/          # GitHub Actions (CI)
├── .clangd, .clang-format, .clang-tidy
├── CMakeLists.txt, CMakePresets.json
├── conanfile.py
└── CHANGELOG.md
```

---

## 4. Flujos de trabajo (día a día)

### 4.1. Debug (desarrollo normal)

```bash
./scripts/configure.sh debug      # solo la primera vez, o si cambias dependencias/Conan
cmake --build --preset debug
ctest --preset debug --output-on-failure
```

Incluye: warnings estrictos, sanitizers (ASan + UBSan), clang-tidy y símbolos de debug completos. Como MSan no es compatible con ASan, es solo para Clang y se debe compilar libc++/libstdc++ instrumentadas con MSan se opto por no añadirla como opción a la configuración.

Para iterar rápido tras el primer `configure`:

```bash
cmake --build --preset debug && ctest --preset debug --output-on-failure
```

Ejecutar/depurar un test concreto:

```bash
./bin/debug/devkit_tests --gtest_filter=CircleTest.*
gdb --args ./bin/debug/devkit_tests --gtest_filter=RectangleTest.AreaIsComputedCorrectly
```

### 4.2. Release

```bash
./scripts/configure.sh release
cmake --build --preset release
ctest --build-config Release --test-dir temp/build/release --output-on-failure
```

Incluye: `-O3`, LTO, símbolos separados (`bin/release/devkit_tests` + `devkit_tests.debug`), sin sanitizers ni análisis estático.

### 4.3. Cppcheck (análisis estático, bajo demanda)

```bash
cmake --build temp/build/debug --target cppcheck
```

### 4.4. Coverage

```bash
./scripts/configure.sh coverage
cmake --build temp/build/coverage
ctest --test-dir temp/build/coverage --output-on-failure
cmake --build temp/build/coverage --target coverage
```

Abre `coverage/index.html` desde el **host** (el volumen está montado, no hace falta copiar nada).

### 4.5. Valgrind (memcheck)

```bash
./scripts/configure.sh valgrind
cmake --build temp/build/valgrind
cmake --build temp/build/valgrind --target memcheck
```

### 4.6. Documentación (Doxygen)

```bash
./scripts/configure.sh debug
cmake --preset debug -DDEVKIT_BUILD_DOCS=ON
cmake --build temp/build/debug --target docs
```

Abre `docs/html/index.html` desde el host.

### 4.7. Formato

```bash
# Verificar (lo que corre en CI)
find inc src app test -name "*.hpp" -o -name "*.cpp" | xargs clang-format --dry-run --Werror

# Aplicar automáticamente
find inc src app test -name "*.hpp" -o -name "*.cpp" | xargs clang-format -i
```

### 4.8. IWYU (include-what-you-use, puntual)

```bash
cmake --preset debug -DENABLE_IWYU=ON
cmake --build --preset debug
```

### 4.9. Benchmarks (Google Benchmark)

Microbenchmarks de la librería (`benchmark/`), desactivados por defecto (a diferencia de tests/app) porque son pesados de compilar y no aportan valor en el ciclo normal de desarrollo. Se activan explícitamente con `-DDEVKIT_BUILD_BENCHMARKS=ON`:

```bash
./scripts/configure.sh debug
cmake --preset debug -DDEVKIT_BUILD_BENCHMARKS=ON
cmake --build --preset debug
./bin/benchmark/devkit_benchmarks
```

**Los benchmarks deben medirse en Release, nunca en Debug** — con sanitizers/optimizaciones desactivadas, los tiempos no son representativos (Google Benchmark incluso avisa con `***WARNING*** Library was built as DEBUG. Timings may be affected.` si detecta esto):

```bash
./scripts/configure.sh release
cmake --preset release -DDEVKIT_BUILD_BENCHMARKS=ON
cmake --build --preset release
./bin/benchmark/devkit_benchmarks
```

Filtrar por nombre (igual que con gtest):

```bash
./bin/benchmark/devkit_benchmarks --benchmark_filter=Circle
```

Ver sección 6.13 para añadir nuevos benchmarks.

### 4.10. Fuzzing (libFuzzer, requiere Clang)

`fuzz/` contiene fuzz targets con [libFuzzer](https://llvm.org/docs/LibFuzzer.html), integrado en Clang (no disponible con GCC). Desactivado por defecto, se activa con `-DDEVKIT_BUILD_FUZZERS=ON` y **exige** compilar con Clang — `Fuzzing.cmake` falla explícitamente con `FATAL_ERROR` si detecta otro compilador, para no dar una falsa sensación de que "funciona" sin sanitizers de fuzzing reales:

```bash
rm -rf temp/build (en caso de que previamente compilaras por defecto (gcc) o con la opcion gcc)
./scripts/configure.sh debug clang
cmake --preset debug -DDEVKIT_BUILD_FUZZERS=ON
cmake --build --preset debug

./bin/fuzz/fuzz_shape_printer
```

**Corpus persistente entre ejecuciones.** Sin argumentos, libFuzzer genera inputs aleatorios en memoria y los descarta al terminar — cada ejecución empieza de cero. Pasándole una carpeta como argumento, libFuzzer **guarda ahí los inputs que descubren nuevos caminos de código** (el "corpus"), y en la siguiente ejecución los reutiliza como punto de partida en vez de generar todo desde cero — el fuzzing se vuelve incremental y más eficaz con cada sesión:

```bash
mkdir -p fuzz/corpus/shape_printer
./bin/fuzz/fuzz_shape_printer fuzz/corpus/shape_printer
```

> `fuzz/corpus/` no se versiona (añádelo a `.gitignore` si no está ya) — es un artefacto local que crece con el uso, no código fuente. Si el fuzzer encuentra un crash, guarda el input exacto que lo provocó en un fichero `crash-<hash>` en el directorio de trabajo actual — consérvalo como caso de test de regresión.

**Limitar la duración con `-max_total_time`** (segundos), imprescindible para no dejarlo corriendo indefinidamente — sin este flag, libFuzzer corre hasta que lo interrumpas manualmente (Ctrl+C):

```bash
./bin/fuzz/fuzz_shape_printer -max_total_time=60 fuzz/corpus/shape_printer
```

Ver sección 6.14 para añadir nuevos fuzz targets.

### 4.11 Añadir hilos

Para aquellos que quieran utilizar hilos simplemente tiene que añadir al CMakeLists.txt raíz
```cmake
find_package(Threads REQUIRED)
```

Y en el target_link_libraries en ru respectiva interfaz PUBLIC|PRIVATE|INTERFACE según el caso de uso del usuario, añadimos:
```cmake
Threads::Threads
```

En CMakeLists.txt raíz y src/CMakeLists.txt hay un ejemplo comentado, ya que, la plantilla nuestra no hace uso de hilos

### 4.12 Añadir otras funcionalidades

En base al apartado 4.11, no solamente los hilos se deben habilitar, otras utilidades también pueden tener la necesidad de ser hanilitadas, ya sea por diseño o por la versión del compilador, algunos ejemplo son:

- Librería Matemática (m)
- Funciones de enlace dinámico (dl)
- Relojes de tiempo real (rt)
- Operaciones Atómicas (atomic)
- Políticas de Ejecución / Parallel STL (TBB)
- Stack Trace (dw / bfd)

### 4.13 Precompiled Header Files (PCH)

Cuando se usa muhco un header como puede ser <string>, este realentiza el proceso de compilación al tener includes dentro los .cpp, con este método solo se compila una vez, por ejmplo en src/CMakeLists.txt:
```cmake
target_precompile_headers(devkit_shapes
    PRIVATE
        <string>
        <memory>
        <fmt/format.h>
)
```

Benchmark y test puedan reutilizarlo (Solo funciona si ambos targets comparten compilador/flags compatibles) añadiendo tras add_executable/target_link_libraries:
```cmake
target_precompile_headers(devkit_tests REUSE_FROM devkit_shapes)
```

En CMake, la funcionalidad REUSE_FROM de target_precompiled_headers permite que un target reutilice el binario de cabecera precompilada (.gch o .pch) ya generado por otro target, ahorrando espacio en disco y tiempo de CPU adicional. Sin embargo, en este proyecto no se debe utilizar REUSE_FROM por los siguientes motivos técnicos:
1. Incompatibilidad Fundamental: PIC vs. PIE

    Librerías (devkit_shapes): Se compilan con el flag -fPIC (Position Independent Code). Es un requisito para que el código de la librería sea reubicable, especialmente si se decide compilar como biblioteca compartida (.so).

    Ejecutables (tests, app, benchmarks): Debido a la política de seguridad definida en Hardening.cmake, los ejecutables se compilan con el flag -fPIE (Position Independent Executable). Esto activa el ASLR (Address Space Layout Randomization), una mitigación crítica contra exploits que aleatoriza las direcciones de memoria en tiempo de ejecución.

El compilador (GCC/Clang) rechaza un PCH si los flags que afectan a la generación de código no coinciden exactamente. Intentar usar un PCH generado con -fPIC en un target con -fPIE provocará el error: created and used with different settings of -fpie.
2. Seguridad sobre Rendimiento (Hardening)

Desactivar el flag de Hardening para permitir la reutilización de los PCH degradaría la postura de seguridad del software. Los beneficios de protección contra ataques de corrupción de memoria (gracias a -fPIE y -pie) son innegociables en una plantilla profesional y superan con creces el ahorro de unos pocos segundos en el tiempo de compilación.
3. Macros y Definiciones de Preprocesador

El hardening inyecta macros adicionales (como _FORTIFY_SOURCE=2) que a menudo solo se aplican en configuraciones de Release u optimizadas. Si un target origen no tiene exactamente las mismas definiciones de preprocesador que el target destino, el PCH será invalidado por el compilador para evitar comportamientos indefinidos (UB).
Recomendación de implementación

Para maximizar la velocidad sin sacrificar la seguridad ni la estabilidad:

    Aislamiento: Cada target debe definir sus propios PCH de forma PRIVATE.

    Propagación de Lista, no de Binario: En lugar de heredar el archivo binario compilado, se recomienda heredar la lista de cabeceras a través de funciones configuradoras (como devkit_configure_target), permitiendo que CMake genere un binario PCH específico y compatible para cada target.

Por útimo en StaticAnalyzers.cmake debemos añadir --extra-arg=-Wno-ignored-gch para si el PCH se compilo con GCC y despues se utiliza Clang y no falle la compilación.

### 4.14 Unity Build

Agrupa todos los ficheros .cpp en menos unidades para reducir los tiempos de compilación, esta desactivado por defecto pero es especialmente en proyectos con muchos ficheros .cpp. Recuerda que puede esconder bugs de ODR, colisiones de simbolos o de macros entre ficheros. Se controla con DEVKIT_ENABLE_UNITY_BUILD (cmake/Unitybuild.cmake), ejemplo:
```bash
cmake --preset release -DDEVKIT_ENABLE_UNITY_BUILD=ON
cmake --build --preset release
```

### 4.15 CPack

Genera instaladores/paquetes (.tar.gz, .deb, .rpm) a partir de tus reglas install() ya existentes, ejemplo de alguna de las variables que configura al final del CMakeLists.txt raíz:
```cmake
if(DEVKIT_IS_TOP_LEVEL)
    set(CPACK_PACKAGE_NAME "devkit")
    set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
    set(CPACK_PACKAGE_VENDOR "Tu Nombre")
    set(CPACK_PACKAGE_CONTACT "tu@email.com")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
    set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_SOURCE_DIR}/LICENSE")
    set(CPACK_GENERATOR "TGZ;DEB")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_CONTACT}")
    include(CPack)
endif()
```

Requiere que el usuario tengo instalado dpkg, dpkg-dev y rmp-build, sin ellos solo se puede generar tar.gz

Ejemplo de uso:
```bash
./scripts/configure.sh release
cmake --build --preset release
cd temp/build/release && cpack
```

Los paquetes se generan dentro de temp/build/release/packages, solo aplica si lo ejecutas tu mismo o via release.yml

Con los paquetes generados el usuario final no tiene porque clonar el repo ni compilar. Instala la libreria dentro de /usr/local/include/ y /usr/local/lib/ listo para enlazar con find_package(devkit)

Esta automatizado para que por parte del desarrollador solo tenga que hacer un push normal con el proceso de ./scripsts/release.sh ya mencionado, y el tercero que quiere instalar la liberia debe ejecutar (ejemplo Fedora con rpm):
```bash
wget https://github.com/eviandeveloper/devkit/releases/download/v0.7.6/devkit-0.7.6-Linux.rpm
sudo dnf install ./devkit-0.7.6-Linux.rpm
cmake -B build
cmake --build build
./build/prueba_devkit
```

para borrar la libreria:
- Fedora
```bash
sudo dnf remove devkit
```

ejemplo de cmake necesario por parte del tercer:
```cmake
cmake_minimum_required(VERSION 3.25)
project(prueba_devkit LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(devkit REQUIRED)

add_executable(prueba_devkit main.cpp)
target_link_libraries(prueba_devkit PRIVATE devkit::shapes)
```

ejemplo de main.cpp del tercero:
```c++
#include <iostream>
#include "devkit/circle.hpp"
#include "devkit/shape_printer.hpp"

int main() {
    devkit::Circle circle(3.0);
    std::cout << devkit::DescribeShape(circle) << '\n';
    return 0;
}
```

En distribuciones basadas en debian:
```bash
apt install -y ./devkit-0.7.6-Linux.deb
```

```bash
apt-get remove devkit
```

### 4.16 Seguridad ante ataques

En cmake/Hardening.cmake se añaden flag para habilitar la protección frente ataques comnues como puede ser la protección de la pila. Estos se aplican solamente a Release, parte de la lista de protecciones esta formada por:
- fstack-protector-strong: añade protecciones de canary
- _FORTIFY_SOURCE=2: Activa comprobaciones adicionales de seguridad proporcionadas por la libc cuando el compilador puede conocer tamaños de buffers.
- /guard:cf: Activa Control Flow Guard (CFG).
- /DYNAMICBASE: Indica al linker que el ejecutable pueda utilizar ASLR (Address Space Layout Randomization).
- /NXCOMPAT: Marca el ejecutable como compatible con DEP/NX, haciendo que determinadas regiones de memoria no sean ejecutables
- fPIE: Compila el código del ejecutable como Position Independent Executable.
- pie: Le dice al linker que genere un ejecutable PIE
- -z relro: Hace que determinadas estructuras utilizadas durante las relocaciones puedan quedar en memoria de solo lectura después de la inicialización.
- -z now: Fuerza la resolución inmediata de símbolos dinámicos en lugar de hacerlo de forma perezosa.
- Full RELRO: ofrece mayor protección que Partial frente a determinadas técnicas de explotación de binarios ELF.

Se aplica por defecto, pero se puede desactivar con:
```bash
cmake --preset release -DDEVKIT_ENABLE_HARDENING=OFF
```

Funciona tanto con generadores de un solo config como multi-config

### 4.17. Recompilación y tests automáticos al guardar (watch mode)

`entr` vigila los ficheros fuente y recompila + corre los tests automáticamente en cada cambio:

\`\`\`bash
./scripts/watch.sh debug
\`\`\`

Útil en sesiones de refactor con TDD. A diferencia de lenguajes interpretados, el ciclo incluye recompilación (mitigada por ccache), así que el feedback no es instantáneo — sigue aportando valor automatizando el "olvidarte de correr los tests" tras cada cambio, pero puede sentirse pesado si tocas ficheros muy seguido con sanitizers/clang-tidy activos.

> Si añades un fichero nuevo (no solo editas uno existente), reinicia `watch.sh` — `entr` no detecta ficheros creados después de arrancar.

Modifica ./scripts/watch.sh a tu gusto en caso de que queria configurarlo para benchmarks, docs, coverage...

Posibles alternativas a entr: watchexec (no esta instalado ya que no esta en el repositorio de fedora oficial y requeriria compilarlo con Rust, añadiendo más dependecias innecesarias)

---

## 5. Por qué siempre hay que usar `scripts/configure.sh`

`cmake --preset <preset>` **no** ejecuta `conan install` por sí solo. Cada preset (`debug`, `release`, `coverage`, `valgrind`) usa su propia carpeta de build (`temp/build/<preset>/`) con su propio `conan_toolchain.cmake`, que Conan debe generar **antes** de que CMake pueda leerlo. `scripts/configure.sh <preset>` hace ambos pasos en el orden correcto:

```bash
./scripts/configure.sh <debug|release|coverage|valgrind> [default|gcc|clang] [static|shared]
```

El segundo argumento (opcional, por defecto `default`) permite elegir el compilador:

```bash
./scripts/configure.sh debug              # perfil 'default' autodetectado (actualmente GCC)
./scripts/configure.sh debug gcc          # fuerza el perfil conan/profiles/fedora-gcc
./scripts/configure.sh debug clang        # fuerza el perfil conan/profiles/fedora-clang
./scripts/configure.sh release clang      # también funciona combinado con cualquier preset
```

> Antes de forzar `gcc`/`clang`, verifica que `conan/profiles/fedora-gcc` y `conan/profiles/fedora-clang` tengan el `compiler.version` correcto para tu imagen (`gcc --version` / `clang --version` dentro del contenedor) — si no coincide, Conan fallará con `Invalid setting`. Si además usas una versión de compilador no incluida en el catálogo de Conan, añádela también a `conan/settings_user.yml` (ver sección 8).

El tercer argumento (opcional, por defecto `static`) permite compilar `devkit_shapes` como biblioteca compartida (`.so`) en vez de estática (`.a`):

```bash
./scripts/configure.sh debug                       # estática (por defecto)
./scripts/configure.sh debug default shared         # compartida (.so)
./scripts/configure.sh release clang shared         # combinable con compilador y preset
```

Ver sección 6.12 para el mecanismo que hace esto posible (`generate_export_header`) y la sección 7.2 para el efecto en consumidores externos vía `FetchContent`.

Al cambiar de compilador o de tipo de enlazado es recomendable limpiar el build previo, ya que los artefactos no son compatibles entre sí:

```bash
rm -rf temp/build
./scripts/configure.sh debug clang shared
```

Solo hace falta volver a ejecutar `configure.sh` si:
- Cambias `conanfile.py` (nueva dependencia, cambio de versión, etc.)
- Borras `temp/build/`
- Cambias de compilador (`gcc` ↔ `clang` ↔ `default`)
- Cambias de tipo de enlazado (`static` ↔ `shared`)
- Es la primera vez que usas ese preset

Para simplemente recompilar tras editar código, basta con `cmake --build --preset <preset>`.

---

## 6. Cómo modificar la configuración del proyecto

### 6.1. Cambiar el estándar de C++

### Ruta: `CMakeLists.txt` (raíz)

```cmake
set(CMAKE_CXX_STANDARD 20)   # cambia a 17, 23, etc.
```

Después, reconfigura desde cero:

```bash
rm -rf temp/build
./scripts/configure.sh debug
```

> Si subes de estándar (por ejemplo a C++23), verifica que la versión de Clang/GCC instalada en el `Dockerfile` lo soporte, y que las dependencias de Conan (`fmt`, `gtest`) tengan un binario compatible con ese `compiler.cppstd` (si no, Conan las recompilará desde fuente automáticamente).

### 6.2. Añadir o quitar warnings

### Ruta: `cmake/CompilerWarnings.cmake`

Edita la lista `CLANG_GCC_WARNINGS` dentro de `devkit_set_project_warnings()`:

```cmake
set(CLANG_GCC_WARNINGS
    -Wall
    -Wextra
    -Wpedantic
    # ... añade o quita flags aquí
)
```

Los flags exclusivos de GCC (`-Wduplicated-cond`, `-Wlogical-op`, etc.) están en el bloque `elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")` — si añades un flag exclusivo de un compilador, ponlo en el bloque correspondiente (`Clang` o `GNU`), no en la lista común, o clang-tidy lo rechazará como "unknown warning option" (ya mitigado globalmente con `--extra-arg=-Wno-unknown-warning-option` en `StaticAnalyzers.cmake`, pero es más limpio evitarlo desde el origen).

Para convertir todos los warnings en errores (o dejar de hacerlo), busca `-Werror` en la misma función.

### 6.3. Añadir, quitar o cambiar optimizaciones de Release

### Ruta: `cmake/Optimizations.cmake`

```cmake
set(SAFE_OPTIMIZATION_FLAGS
    -O3
    -DNDEBUG
    -fomit-frame-pointer
    -funroll-loops
    # añade aquí, solo flags que NO alteren la semántica del programa
)
```

**Evita** añadir `-ffast-math`, `-funsafe-math-optimizations` o `-march=native` — rompen precisión IEEE754 o portabilidad del binario (ver comentarios en el propio fichero para el razonamiento completo).

### 6.4. Activar/desactivar sanitizers

### Ruta: `cmake/Sanitizers.cmake`

Controlado por la opción `ENABLE_SANITIZERS` (por defecto `ON` en Debug). Para usar ThreadSanitizer en vez de ASan+UBSan:

```bash
cmake --preset debug -DENABLE_THREAD_SANITIZER=ON
```

### 6.5. Añadir una nueva librería de terceros (Conan)

1. Busca el paquete en [ConanCenter](https://conan.io/center) para confirmar nombre y versión exacta.

2. Añádelo en `conanfile.py`:

   ### Ruta: `conanfile.py`

   ```python
   def requirements(self):
       self.requires("fmt/11.0.2")
       self.requires("nlohmann_json/3.11.3")   # <-- nueva dependencia
   ```

   Si es una dependencia **solo para tests/benchmarks** (no para producción), va en `build_requirements()` con `self.test_requires(...)` en vez de `requirements()` — así se hizo con `gtest` y `benchmark`.

3. Si el paquete tiene opciones relevantes (por ejemplo `shared`), añádelas en `configure()`:

   ```python
   def configure(self):
       self.options["fmt"].shared = False
       self.options["nlohmann_json"].shared = False
   ```

4. Enlázala al target que la necesite (`src/CMakeLists.txt`, `app/CMakeLists.txt` o `test/CMakeLists.txt`):

   ```cmake
   find_package(nlohmann_json REQUIRED)   # en el CMakeLists.txt raíz, junto a find_package(fmt REQUIRED)

   target_link_libraries(devkit_shapes
       PRIVATE
           fmt::fmt
           nlohmann_json::nlohmann_json
   )
   ```

   Usa `PRIVATE` si la dependencia solo se usa en los `.cpp` (no se expone en ningún `.hpp` público de `inc/`), o `PUBLIC` si tipos de esa librería aparecen en la interfaz pública de tus headers.

5. Reconfigura (Conan detecta el cambio en `conanfile.py` y descarga/compila la nueva dependencia):

   ```bash
   rm -rf temp/build
   ./scripts/configure.sh debug
   ```

### 6.6. Añadir un nuevo `.cpp`/`.hpp` a la librería

1. Header en `inc/devkit/nuevo.hpp`, implementación en `src/nuevo.cpp`.
2. Añade el `.cpp` a la lista de fuentes en `src/CMakeLists.txt`:

   ```cmake
   add_library(devkit_shapes
       circle.cpp
       rectangle.cpp
       shape_printer.cpp
       nuevo.cpp   # <-- añadir
   )
   ```

   > Nota: `add_library` **no** lleva `STATIC` explícito a propósito — así respeta `BUILD_SHARED_LIBS`, permitiendo compilar como `.so` cuando se pide (ver sección 6.12).

3. Si la nueva clase/función es parte de la **API pública** (se usa fuera de `devkit`), añade `#include "devkit/export.h"` y marca la clase/función con `DEVKIT_API` — necesario para que sus símbolos se exporten correctamente en modo compartido:

   ```cpp
   #pragma once

   #include "devkit/export.h"

   namespace devkit {

   class DEVKIT_API Nuevo {
       ...
   };

   }  // namespace devkit
   ```

4. Recompila (no hace falta `configure.sh`, solo build):

   ```bash
   cmake --build --preset debug
   ```

### 6.7. Añadir código al ejecutable (`app/`)

Añade el `.cpp` a `add_executable` en `app/CMakeLists.txt`:

```cmake
add_executable(devkit_app
    main.cpp
    nuevo_fichero.cpp
)
```

Si ese fichero necesita una dependencia nueva (de Conan o de `inc/`), añádela en el `target_link_libraries(devkit_app PRIVATE ...)` del mismo fichero.

### 6.8. Añadir nuevos tests

Crea `test/nuevo_test.cpp` y añádelo a `test/CMakeLists.txt`:

```cmake
add_executable(devkit_tests
    circle_test.cpp
    rectangle_test.cpp
    shape_printer_test.cpp
    shape_mock_test.cpp
    nuevo_test.cpp   # <-- añadir
)
```

### 6.9. Cambiar el compilador por defecto (GCC ↔ Clang)

`scripts/configure.sh` acepta un segundo argumento para elegir el compilador (ver sección 5):

```bash
rm -rf temp/build
./scripts/configure.sh debug clang    # o 'gcc' para forzar GCC explícitamente
```

Antes de usarlo, verifica que `conan/profiles/fedora-clang` (o `fedora-gcc`) tenga la versión de compilador correcta (`compiler.version=...`) — debe coincidir con lo que reporta `clang --version` / `gcc --version` dentro del contenedor. Si la versión instalada no está en el catálogo interno de Conan, añádela también a `conan/settings_user.yml`.

### 6.10. Cambiar el estilo de formato (`.clang-format`) o las reglas de `clang-tidy`

- Estilo de formato: edita `.clang-format` en la raíz (actualmente basado en Google Style con ajustes).
- Reglas de análisis: edita `.clang-tidy` — la sección `Checks:` controla qué categorías se activan/desactivan, y `CheckOptions:` controla convenciones de nombres (`CamelCase`, `lower_case`, etc.).

Tras cualquier cambio en `.clang-tidy`, no hace falta reconfigurar CMake, solo recompilar:

```bash
cmake --build --preset debug
```

### 6.11. Al editar cualquier fichero de `cmake/*.cmake`: usa `PROJECT_SOURCE_DIR`, no `CMAKE_SOURCE_DIR`

Todos los módulos propios de `devkit` (`cmake/*.cmake`, `src/CMakeLists.txt`, `app/CMakeLists.txt`, `test/CMakeLists.txt`, `benchmark/CMakeLists.txt`, el `CMakeLists.txt` raíz) referencian rutas de `devkit` usando `PROJECT_SOURCE_DIR`/`PROJECT_BINARY_DIR`, **no** `CMAKE_SOURCE_DIR`/`CMAKE_BINARY_DIR`. Es una regla deliberada, no un detalle de estilo:

- `CMAKE_SOURCE_DIR` es **global**: siempre apunta al proyecto top-level real, sea `devkit` o quien lo esté consumiendo (por ejemplo, vía `FetchContent`).
- `PROJECT_SOURCE_DIR` es **relativo al último `project()` evaluado**: dentro de `devkit/CMakeLists.txt`, siempre apunta a la raíz de `devkit`, esté embebido o no.

Si usas `CMAKE_SOURCE_DIR` en un fichero de `devkit` y alguien te consume vía `FetchContent`, ese `include()`/esa ruta apuntará a la raíz del proyecto **consumidor**, no a la de `devkit`, y fallará con errores como `include could not find requested file`.

**Únicas dos excepciones**, donde `CMAKE_SOURCE_DIR`/`CMAKE_BINARY_DIR` sí son correctos:

- `cmake/Cppcheck.cmake` — `compile_commands.json` siempre se genera en la raíz del build del proyecto top-level real, nunca en `PROJECT_BINARY_DIR` de una subunidad.
- La detección de `DEVKIT_IS_TOP_LEVEL` en `CMakeLists.txt` (`if(CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)`) — necesita comparar la variable global contra la local precisamente para saber si son la misma.

### 6.12. Compilar `devkit_shapes` como biblioteca compartida (`.so`)

Por defecto, `devkit_shapes` se compila **estática** (`.a`). Para compilarla como compartida:

```bash
rm -rf temp/build
./scripts/configure.sh debug default shared
cmake --build --preset debug
```

Verifica que el `.so` se generó y que los símbolos están correctamente exportados:

```bash
ldd bin/debug/devkit_tests | grep devkit
nm -D temp/build/debug/src/libdevkit_shapes.so | grep -i circle   # deben aparecer como 'T' (exportado)
```

**Por qué esto funciona sin exponer todo por accidente:** el proyecto fija `CMAKE_CXX_VISIBILITY_PRESET hidden` globalmente (`cmake/StandardProjectSettings.cmake`) — buena práctica que oculta todos los símbolos por defecto en una biblioteca compartida. Para que las clases/funciones públicas (`Circle`, `Rectangle`, `Shape`, `DescribeShape`) sigan siendo visibles pese a eso, `src/CMakeLists.txt` usa `generate_export_header()` de CMake, que genera automáticamente `inc/devkit/export.h` con el macro `DEVKIT_API`. Cada clase/función pública se marca explícitamente:

```cpp
class DEVKIT_API Circle final : public Shape { ... };
[[nodiscard]] DEVKIT_API std::string DescribeShape(const Shape& shape);
```

`DEVKIT_API` se expande de forma distinta según el contexto:
- Compilando `devkit_shapes` como `.so` → exporta el símbolo (`visibility("default")`).
- Consumiendo el `.so` ya compilado → no hace falta nada especial en GCC/Clang.
- Compilando como `.a` (estático, el caso por defecto) → el macro no hace nada.

Si añades una nueva clase/función pública a la librería, recuerda marcarla con `DEVKIT_API` (ver sección 6.6) — si no, quedará oculta en modo compartido aunque funcione perfectamente en modo estático (el bug pasaría desapercibido hasta que alguien active `shared`).

### 6.13. Añadir nuevos benchmarks

1. Crea `benchmark/nuevo_benchmark.cpp` siguiendo el patrón de los existentes — **sin** `BENCHMARK_MAIN()`, ver nota abajo:

   ```cpp
   #include <benchmark/benchmark.h>

   #include "devkit/nuevo.hpp"

   namespace {

   void BM_NuevoOperacion(benchmark::State& state) {
       for (auto _ : state) {
           benchmark::DoNotOptimize(/* operación a medir */);
       }
   }
   BENCHMARK(BM_NuevoOperacion);

   }  // namespace
   ```

2. Añádelo a `benchmark/CMakeLists.txt`:

   ```cmake
   add_executable(devkit_benchmarks
       circle_benchmark.cpp
       rectangle_benchmark.cpp
       nuevo_benchmark.cpp   # <-- añadir
   )
   ```

3. Recompila con benchmarks activados (ver sección 4.9):

   ```bash
   cmake --preset debug -DDEVKIT_BUILD_BENCHMARKS=ON
   cmake --build --preset debug
   ```

> **El `main()` no se escribe a mano ni con la macro `BENCHMARK_MAIN()` en ningún `.cpp`.** `benchmark/CMakeLists.txt` enlaza el target `benchmark::benchmark_main` (además de `benchmark::benchmark`), que ya provee un `main()` completo — exactamente el mismo patrón que `GTest::gtest_main` en `test/CMakeLists.txt`. Si además se usara `BENCHMARK_MAIN()` en algún `.cpp`, habría dos definiciones de `main()` y el enlazado fallaría.
>
> Si defines `RUNTIME_OUTPUT_DIRECTORY` u otra propiedad de salida por-target, fíjala también por-configuración (`RUNTIME_OUTPUT_DIRECTORY_DEBUG`, `_RELEASE`, etc. — ver `benchmark/CMakeLists.txt`) — las propiedades específicas de configuración, ya inicializadas por las variables globales del `CMakeLists.txt` raíz, tienen prioridad sobre la genérica y la sobreescriben silenciosamente si no se fija también la versión específica (ver tabla de la sección 10).

### 6.14. Añadir un nuevo fuzz target

1. Crea `fuzz/nuevo_fuzz.cpp` con la función de entrada que espera libFuzzer:

   ```cpp
   #include <cstdint>
   #include <cstddef>

   #include "devkit/nuevo.hpp"

   extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
       // convierte data/size al tipo de entrada real y ejercita la función,
       // sin asumir nada sobre el contenido: el objetivo es no crashear ni
       // disparar UB con CUALQUIER secuencia de bytes.
       return 0;
   }
   ```

2. Regístralo en `fuzz/CMakeLists.txt` con `devkit_add_fuzzer` (un target por fichero):

   ```cmake
   devkit_add_fuzzer(fuzz_shape_printer shape_printer_fuzz.cpp)
   devkit_add_fuzzer(fuzz_nuevo nuevo_fuzz.cpp)   # <-- añadir
   ```

3. Compila con Clang y benchmarks activados (ver sección 4.10):

   ```bash
   ./scripts/configure.sh debug clang
   cmake --preset debug -DDEVKIT_BUILD_FUZZERS=ON
   cmake --build --preset debug
   ./bin/fuzz/fuzz_nuevo -max_total_time=60 fuzz/corpus/nuevo
   ```

> Cada fuzz target es independiente (un `add_executable` por `devkit_add_fuzzer`), con su propia carpeta de corpus recomendada bajo `fuzz/corpus/<nombre>/` — no compartas corpus entre fuzz targets distintos, ya que cada uno explora un espacio de entrada diferente.

---

# 7. Cambiar Google Test por Catch2

Como tener dos frameworks diferentes para ejecutar tests no tiene mucho sentido, se acabo eligiendo Google Test en vez de Catch2. Para aquellos no contentos con esta idea, acontinuación se les indica que deben modificar:

- En conanfile.py cambiar:
```python
def build_requirements(self):
        self.test_requires("gtest/1.15.0")
        self.test_requires("benchmark/1.9.0")
```

por esta posible versión:
```python
def build_requirements(self):
        self.test_requires("catch2/3.7.1")
        self.test_requires("benchmark/1.9.0")
```

En test/CMakeLists.txt se debe modificar:
- El paquete a buscar:
```cmake
find_package(GTest REQUIRED)
```
debe ser modificado por:
```cmake
find_package(Catch2 REQUIRED)
```

- Cambiar el main de Google Test por el de Catch2:
```cmake
target_link_libraries(devkit_tests
    PRIVATE
        devkit::shapes
        GTest::gtest
        GTest::gtest_main
        GTest::gmock
)
```

debe ser modificado por:
```cmake
target_link_libraries(devkit_tests PRIVATE devkit::shapes Catch2::Catch2WithMain)
```

- Modificar el descrubimiento:
```cmake
include(GoogleTest)
gtest_discover_tests(devkit_tests
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    PROPERTIES LABELS "unit"
)
```

debe ser modificado por:
```cmake
include(Catch)
catch_discover_tests(devkit_tests
  WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
  PROPERTIES LABELS "unit"
)
```

Obviamente los test/test.cpp se deben reescribir con las utilidades ofrecidad por Catch2 o no compilaran. Nuevamente se desaconseja utilizar ambos frameworks a la vez ya que solamente añade complejidad, salvo que se este realizando una migración de un framework al otro, lo cual se desaconseja salvo causa critica. Respecto a otras configuraciones como el coverage deberian seguir funcionado sin necesidad de modificaciones. Por último ten en cuenta que a la fecha que se escribe este README Catch2 no tiene soporte para mocks a diferencia de Google Test, en caso de ser de relevancia para usted le recomiendo comprobar si Catch2 añadio la funcionalidad, si no tendra que realizar ajustes manuales a nivel de código para conseguir el efecto deseado.

Por último si la configuracion previa usaba Google Test y no se borro, se recomienda limpiar la cache:
```bash
rm -rf temp/build
./scripts/configure.sh debug
cmake --build --preset debug
ctest --preset debug --output-on-failure
```

---

## 8. Reutilizar `devkit_shapes` en otro proyecto

La librería (`devkit_shapes`, expuesta como `devkit::shapes`) está preparada para ser consumida de cuatro formas distintas. Elige según el caso.

### 8.1. Monorepo / mismo árbol de CMake (`add_subdirectory`)

Si `devkit/` vive como subcarpeta de un proyecto más grande:

```cmake
add_subdirectory(devkit)
target_link_libraries(mi_app PRIVATE devkit::shapes)
```

No requiere nada adicional — el `ALIAS devkit::shapes` ya existe en `src/CMakeLists.txt`.

### 8.2. `FetchContent` (otro repo Git, sin gestor de paquetes)

```cmake
include(FetchContent)
FetchContent_Declare(
    devkit
    GIT_REPOSITORY https://github.com/tu-usuario/devkit.git
    GIT_TAG        v0.1.0
)
FetchContent_MakeAvailable(devkit)

add_executable(mi_app main.cpp)
target_link_libraries(mi_app PRIVATE devkit::shapes)
```

Por defecto, si `devkit` no es el proyecto top-level, `DEVKIT_BUILD_TESTS` y `DEVKIT_BUILD_APP` se desactivan automáticamente (no hace falta que el consumidor los apague a mano), y `CMAKE_CXX_STANDARD` respeta el que ya haya fijado el proyecto padre si existe.

**`fmt` se resuelve automáticamente.** `devkit` comprueba si el target `fmt::fmt` ya existe (por ejemplo, traído por Conan) y, si no, lo trae él mismo vía `FetchContent` — el consumidor no necesita declarar `fmt` por su cuenta para que `devkit::shapes` compile. Si tu propio código (no solo `devkit`) usa `fmt` directamente, sí debes añadir `fmt::fmt` a tu propio `target_link_libraries`, ya que `devkit_shapes` lo linka como `PRIVATE` y no lo propaga.

**Los sanitizers, si están activos en `devkit` (Debug), sí se propagan y son responsabilidad del consumidor.** Como `devkit_shapes` es una biblioteca estática, `-fsanitize=address,undefined` se declara `PUBLIC` en `cmake/Sanitizers.cmake` — cualquier target que enlace contra `devkit::shapes` en modo Debug heredará esos flags automáticamente (necesario, ya que mezclar código con y sin sanitizers en el mismo binario no es seguro). Esto implica que:

- Tu proyecto consumidor necesita tener instalado el runtime de sanitizers de su compilador (`libasan`, `libubsan` — en Fedora: `sudo dnf install libasan libubsan`) si compila en Debug.
- Si no quieres esa dependencia, define tu propio preset con `CMAKE_BUILD_TYPE=Release` (`devkit` desactiva los sanitizers fuera de Debug) — ver ejemplo abajo.

**`CMakePresets.json` no se hereda vía `FetchContent`.** Los presets de `devkit` (`debug`, `release`, `coverage`, `valgrind`) son internos a su propio repo y no están disponibles para el consumidor. Si quieres un preset `release` en tu propio proyecto:

```json
{
  "version": 6,
  "cmakeMinimumRequired": { "major": 3, "minor": 25, "patch": 0 },
  "configurePresets": [
    {
      "name": "release",
      "generator": "Ninja",
      "binaryDir": "${sourceDir}/build-release",
      "cacheVariables": { "CMAKE_BUILD_TYPE": "Release" }
    }
  ],
  "buildPresets": [
    { "name": "release", "configurePreset": "release" }
  ]
}
```

Al fijar `CMAKE_BUILD_TYPE=Release` en tu propio preset, `devkit` compila `devkit_shapes` con `-O3`+LTO y sin sanitizers, igual que en su propio flujo interno — sin que tengas que configurar nada adicional.

**`BUILD_SHARED_LIBS` sí tiene efecto para un consumidor vía `FetchContent`, y se controla desde tu propio `CMakeLists.txt`** (no hay equivalente al flag `shared` de Conan cuando no usas Conan). Como `add_library(devkit_shapes ...)` no fija `STATIC`/`SHARED` explícitamente (ver sección 6.12), respeta la variable global `BUILD_SHARED_LIBS` del proyecto que lo embebe:

```cmake
# Antes de FetchContent_MakeAvailable(devkit)
set(BUILD_SHARED_LIBS ON)   # devkit_shapes se compilará como .so

FetchContent_MakeAvailable(devkit)
```

O equivalentemente, desde la línea de comandos al configurar tu propio proyecto: `cmake --preset default -DBUILD_SHARED_LIBS=ON`. Ambas formas funcionan porque `BUILD_SHARED_LIBS` es una única variable de caché compartida por todo el árbol de build (incluida la subunidad de `devkit` traída por `FetchContent`), no algo que se herede o configure por separado.

No hace falta ningún paso adicional para que el ejecutable encuentre el `.so` en tiempo de ejecución: CMake fija automáticamente el RPATH del binario para apuntar a la carpeta de build donde queda `libdevkit_shapes.so` (dentro de `build/_deps/devkit-build/src/`), así que `./mi_proyecto` funciona directamente sin tocar `LD_LIBRARY_PATH`. Esto cambia si luego **instalas** el binario fuera del árbol de build (`cmake --install`) — en ese caso, gestiona el RPATH de instalación como en cualquier proyecto CMake con dependencias compartidas.

### 8.3. `cmake --install` (sin Conan)

```bash
# Dentro del contenedor, en devkit/
cmake --preset release -DDEVKIT_BUILD_TESTS=OFF -DDEVKIT_BUILD_APP=OFF
cmake --build --preset release
cmake --install temp/build/release --prefix /ruta/de/instalacion
```

Desde el otro proyecto:

```cmake
find_package(devkit REQUIRED PATHS /ruta/de/instalacion)
target_link_libraries(mi_app PRIVATE devkit::shapes)
```

### 8.4. Paquete Conan (`conan create` + `test_package`)

`devkit/conanfile.py` es una receta **dual**: sirve tanto para instalar tus propias dependencias (`fmt`, `gtest`, `benchmark`) durante el desarrollo local, como para empaquetar `devkit_shapes` como un paquete Conan consumible por terceros. La distinción se resuelve automáticamente vía el flag `-c user.devkit:local_dev=True` que `scripts/configure.sh` ya pasa por ti — no hace falta que lo gestiones manualmente en el día a día.

Construir y validar el paquete localmente:

```bash
conan create . --build=missing
```

Esto compila `devkit_shapes` (sin `app/`, `test/` ni `benchmark/`), lo empaqueta, y ejecuta `test_package/` — un consumidor de prueba que hace `find_package(devkit)` y verifica que `devkit::shapes` funciona correctamente. Si termina sin errores, el paquete es válido.

Cómo lo usaría otro proyecto (una vez publicado en un remote):

```python
# conanfile.py del otro proyecto
def requirements(self):
    self.requires("devkit/0.1.0")
```
```cmake
find_package(devkit REQUIRED)
target_link_libraries(mi_app PRIVATE devkit::shapes)
```

**Publicar el paquete para que otros lo descarguen** requiere subirlo a un remote (no basta con `conan create`, que solo lo deja en tu caché local):

```bash
conan remote add mi-remote https://mi-artifactory.com/artifactory/api/conan/mi-repo
conan upload devkit/0.1.0 -r mi-remote --confirm
```

> ConanCenter (el remote público oficial) no es adecuado para este proyecto: está pensado para librerías de terceros con un ciclo de vida estable, no para plantillas de proyecto. Si necesitas distribución pública gratuita sin montar infraestructura propia, `FetchContent` sobre un tag de Git (sección 7.2) es la vía más simple; para uso interno en una organización, un remote propio (Artifactory, Cloudsmith, etc.) es la opción recomendada.

### 8.5. `main()` opcional provisto por la librería (`devkit::shapes_main`)

Si un consumidor quiere un binario funcional lo antes posible sin escribir su propio `main()`, `devkit` expone un `main()` de ejemplo como target **separado y opcional**: `devkit::shapes_main`.

```cmake
include(FetchContent)
FetchContent_Declare(
    devkit
    GIT_REPOSITORY https://github.com/tu-usuario/devkit.git
    GIT_TAG        v0.4.2
)

set(DEVKIT_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(DEVKIT_BUILD_APP OFF CACHE BOOL "" FORCE)
set(DEVKIT_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)

FetchContent_MakeAvailable(devkit)

# mi_logica.cpp NO define main() — lo provee devkit::shapes_main
add_executable(mi_proyecto src/mi_logica.cpp)

target_link_libraries(mi_proyecto
    PRIVATE
        devkit::shapes_main   # ya arrastra devkit::shapes transitivamente
        fmt::fmt
)
```

Como tenemos ahora main separado debemos cambiar la receta para que vea ambas
```python
def package_info(self):
        #self.cpp_info.libs = ["devkit_shapes"]
        #self.cpp_info.set_property("cmake_target_name", "devkit::shapes")
        #self.cpp_info.set_property("cmake_file_name", "devkit")
        # Componente principal (Lógica)
        self.cpp_info.components["shapes"].libs = ["devkit_shapes"]
        self.cpp_info.components["shapes"].requires = ["fmt::fmt"]

        # Componente del Main
        self.cpp_info.components["shapes_main"].libs = ["devkit_shapes_main"]
        self.cpp_info.components["shapes_main"].requires = ["shapes"]
```

```bash
cmake --preset default                          # estática
cmake --preset default -DBUILD_SHARED_LIBS=ON    # o compartida
cmake --build --preset default
./build/mi_proyecto
```

**Por qué es un target aparte, no parte de `devkit_shapes`:** si el `main()` viviera dentro de la propia librería `devkit_shapes`, cualquiera que la enlazara junto a su propio `main()` (el caso normal, como `devkit_app` o `mi_proyecto` con `mi_logica.cpp` propio) tendría **dos** definiciones de `main()` y el enlazado fallaría. Separándolo en `devkit_shapes_main` (`src/devkit_main.cpp`, con `target_link_libraries(devkit_shapes_main PUBLIC devkit_shapes)`), el consumidor **elige** si quiere ese `main()` (enlazando `devkit::shapes_main`) o el suyo propio (enlazando solo `devkit::shapes`) — nunca ambos a la vez. Es el mismo principio que discutimos para `benchmark::benchmark_main`/`GTest::gtest_main`: solo tiene sentido cuando el propio framework necesita controlar el punto de entrada; aquí se ofrece como una comodidad opcional, no como el comportamiento por defecto.

Si no necesitas este `main()` de ejemplo (el caso más común, cuando tu proyecto ya tiene su propia lógica de arranque), simplemente enlaza `devkit::shapes` como en el resto de ejemplos de esta sección — `devkit::shapes_main` es puramente opt-in.

En main_injection/ tambien se muestra un ejemplo pequeño haciendo uso del main proporcionado por la libreria.

---

## 9. Cómo actualizar la versión correctamente

Este proyecto sigue [Versionado Semántico](https://semver.org/lang/es/) (`MAJOR.MINOR.PATCH`):

- **PATCH** (`0.1.0` → `0.1.1`): corrección de bugs, sin cambios en la API pública.
- **MINOR** (`0.1.0` → `0.2.0`): añades funcionalidad nueva (p. ej. una clase `Triangle`) sin romper código existente.
- **MAJOR** (`0.1.0` → `1.0.0`): cambias la API pública de forma incompatible.

Tanto `write_basic_package_version_file(... COMPATIBILITY SameMajorVersion)` (CMake) como cualquier consumidor de Conan que fije un rango de versión asumen que sigues este esquema — no es opcional si otros dependen de tu librería.

### 9.1. Dónde vive el número de versión

Hay **dos** sitios que deben mantenerse sincronizados manualmente (CMake no puede leer el `conanfile.py` y viceversa):

| Fichero | Línea |
|---|---|
| `CMakeLists.txt` | `project(devkit VERSION 0.1.0 ...)` |
| `conanfile.py` | `version = "0.1.0"` |

Todo lo demás se deriva automáticamente de `CMakeLists.txt`: `devkit::version::kVersionString` (vía `version/version.h.in`), la versión mostrada en Doxygen, y `devkitConfigVersion.cmake`.

### 9.2. Flujo recomendado al publicar una nueva versión

```bash
# 1. Actualiza el número en AMBOS ficheros:
#    - CMakeLists.txt → project(... VERSION 0.2.0 ...)
#    - conanfile.py    → version = "0.2.0"

# 2. Verifica que todo compila y los tests pasan con la nueva versión
rm -rf temp/build
./scripts/configure.sh debug
cmake --build --preset debug
ctest --preset debug --output-on-failure

# 3. Verifica que el paquete Conan también se construye y valida correctamente
conan create . --build=missing

# 4. Actualiza CHANGELOG.md (mueve las entradas de [Unreleased] a la nueva versión)

# 5. Commit, tag y push — el tag DEBE coincidir con la versión (prefijo 'v')
git add CMakeLists.txt conanfile.py CHANGELOG.md
git commit -m "Bump version to 0.2.0"
git tag -a v0.2.0 -m "Release 0.2.0"
git push origin main --tags

# 6. Si distribuyes vía Conan a un remote propio:
conan upload devkit/0.2.0 -r mi-remote --confirm
```

El tag `v0.2.0` es lo que un consumidor externo usará en `FetchContent`:

```cmake
FetchContent_Declare(
    devkit
    GIT_REPOSITORY https://github.com/tu-usuario/devkit.git
    GIT_TAG        v0.2.0
)
```

Cambian v0.2.0 por main en caso de querer usar siempre la ultima versión

### 9.3. Usa `scripts/release.sh` para evitar desincronizar los dos ficheros

En vez de editar `CMakeLists.txt` y `conanfile.py` a mano (fácil olvidar uno de los dos), usa el script auxiliar:

```bash
./scripts/release.sh 0.2.0
```

Esto actualiza ambos ficheros de forma atómica. Después, sigue desde el paso 4 del flujo anterior (`CHANGELOG.md`, commit, tag, push). Además el script muestra un mensaje indicando los siguientes/comandos pasos a realizar.

### 9.4. `CHANGELOG.md`

El proyecto mantiene un `CHANGELOG.md` en la raíz siguiendo [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/). Cada cambio relevante se anota primero bajo `[Unreleased]`, y al hacer un release esa sección se renombra con la versión y fecha correspondientes, dejando `[Unreleased]` vacío para el siguiente ciclo.

### 9.5. Errores comunes a evitar

- **Tag sin actualizar `project(VERSION ...)`**: un consumidor que use `GIT_TAG v0.2.0` obtendría código correcto, pero `devkit::version::kVersionString` seguiría reportando la versión antigua — inconsistencia silenciosa. Usa `scripts/release.sh` para evitarlo.
- **Cambiar la API pública sin subir el MAJOR**: rompe a cualquier consumidor que fije `devkit/[>=0.1.0 <1.0.0]` en su `conanfile.py`, ya que confían en que los minors son compatibles hacia atrás.
- **Olvidar `conan create . --build=missing` antes de publicar**: si el `CMakeLists.txt` cambió de forma incompatible con el empaquetado (por ejemplo, un nuevo `.cpp` no añadido a `install()`), solo este comando lo detecta antes de subir el paquete a un remote.

---

## 10. Añadir nuevas herramientas al entorno (Dockerfile)

Si necesitas una herramienta nueva del sistema (por ejemplo, otro compilador, un profiler distinto, etc.):

1. Añádela a la lista de `dnf install` en `docker/Dockerfile`.
2. Si es un paquete de Python (como `conan`/`gcovr`), añádela con versión fijada en `docker/requirements.txt`.
3. Reconstruye la imagen:

   ```bash
   docker-compose -f docker/docker-compose.yml down
   docker-compose -f docker/docker-compose.yml build
   docker-compose -f docker/docker-compose.yml up -d
   docker-compose -f docker/docker-compose.yml exec dev-env bash
   ```

> **Importante:** cualquier instalación hecha en caliente dentro del contenedor (`sudo dnf install ...` mientras estás dentro) se pierde al reconstruir la imagen. Si algo funciona probándolo así, siempre hay que trasladarlo también al `Dockerfile` para que quede persistente.

---

## 11. Resolución de problemas comunes

| Síntoma | Causa habitual | Solución |
|---|---|---|
| `Permission denied` al hacer `ls` dentro del contenedor | SELinux bloqueando el bind mount | Verifica que `docker-compose.yml` monte el proyecto con `:z` (`..:/home/dev/project:z`) |
| `Could not find toolchain file: conan_toolchain.cmake` | Ejecutaste `cmake --preset X` sin haber corrido `conan install` antes | Usa `./scripts/configure.sh X` en vez de `cmake --preset X` directamente |
| Un cambio en un fichero de configuración (Dockerfile, perfiles Conan, `.clang-tidy`...) no se refleja tras reconstruir | Caché de `docker-compose build` usando `buildx bake` | Asegúrate de que existe `docker/.env` con `COMPOSE_BAKE=false`; si persiste, `docker buildx prune -a -f` |
| `Invalid setting 'XX' is not a valid 'settings.compiler.version'` en `conan install` | La versión del compilador del sistema es más reciente que el catálogo interno de Conan | Añade la versión a `conan/settings_user.yml` |
| `cannot find libasan.so`/`libubsan.so` al linkar en Debug | Falta el paquete de runtime de sanitizers | Instala `libasan`, `libubsan`, `libtsan` en el `Dockerfile` |
| `undefined reference` al linkar en Release, pese a que el símbolo existe en la librería | `strip`/`objcopy` aplicado sobre una biblioteca estática (`.a`) con LTO | La separación de símbolos de debug (`cmake/Optimizations.cmake`) debe excluir targets `STATIC_LIBRARY` — solo aplica a ejecutables/`.so` |
| `unknown warning option` en clang-tidy sobre flags como `-Wduplicated-cond` | clang-tidy usa su propio front-end de Clang, no reconoce flags exclusivos de GCC | Ya mitigado con `--extra-arg=-Wno-unknown-warning-option` en `cmake/StaticAnalyzers.cmake` |
| `CMake Error: No se permiten builds in-source` al ejecutar `conan create .` | `conanfile.py` sin `layout()`, o `layout()` mal configurado, hace coincidir source y build folder | Usa `cmake_layout(self)` en `layout()`, condicionado a que no se haya pasado `-c user.devkit:local_dev=True` (ver sección 7.4) |
| Rutas de build duplicadas (`temp/build/debug/temp/build/Debug/...`) al ejecutar `scripts/configure.sh` | `layout()` del `conanfile.py` interfiere con `--output-folder` | Añade el flag `-c user.devkit:local_dev=True` en `scripts/configure.sh` y haz que `layout()` retorne temprano si esa conf está presente |
| `include could not find requested file: StandardProjectSettings` (u otro módulo) al consumir `devkit` vía `FetchContent` | Un fichero de `cmake/` o el `CMakeLists.txt` usa `CMAKE_SOURCE_DIR` (global) en vez de `PROJECT_SOURCE_DIR` (relativo a `devkit`) | Ver sección 6.11 — sustituye por `PROJECT_SOURCE_DIR`/`PROJECT_BINARY_DIR`, salvo en `cmake/Cppcheck.cmake` y la detección de `DEVKIT_IS_TOP_LEVEL` |
| `find_package(fmt REQUIRED)` falla al consumir `devkit` vía `FetchContent` sin Conan | `devkit` asumía que `fmt` ya estaba instalado externamente | Ya mitigado: `devkit` comprueba `if(NOT TARGET fmt::fmt)` y lo trae vía `FetchContent` si hace falta (ver sección 7.2) |
| `undefined reference to __asan_*`/`__ubsan_*` al enlazar un ejecutable que consume `devkit::shapes` vía `FetchContent` | Los flags de sanitizer de `devkit_shapes` (biblioteca estática) no se propagaban al consumidor | Ya mitigado: `cmake/Sanitizers.cmake` declara los flags como `PUBLIC`. Si aun así falla, instala el runtime (`libasan`/`libubsan`) en el sistema del consumidor, o compílalo en Release (ver sección 7.2) |
| `-DBUILD_SHARED_LIBS=ON` no tiene efecto, `devkit_shapes` sigue compilando estático | `add_library(devkit_shapes STATIC ...)` con el tipo fijado explícitamente ignora `BUILD_SHARED_LIBS` | Ya corregido: `add_library(devkit_shapes ...)` sin `STATIC`/`SHARED` explícito (ver sección 6.12) |
| Al pasar `-o shared=True` a `conan install`, sale el warning `Unscoped option definition is ambiguous` | Conan 2 no sabe si la opción aplica solo a `devkit` o también a sus dependencias (`fmt`, `gtest`) | Usa `-o "&:shared=True"` (scope explícito al paquete raíz) — ya aplicado en `scripts/configure.sh` al usar el tercer argumento `shared` |
| Símbolos de una clase/función pública ausentes en `libdevkit_shapes.so` (`nm -D` no la muestra) | Falta el macro `DEVKIT_API` en esa clase/función — `CMAKE_CXX_VISIBILITY_PRESET=hidden` la oculta por defecto | Añade `#include "devkit/export.h"` y marca la clase/función con `DEVKIT_API` (ver sección 6.12) |
| Un ejecutable con `RUNTIME_OUTPUT_DIRECTORY` fijado por `set_target_properties` (p. ej. `devkit_benchmarks`) sigue apareciendo en `bin/debug/` en vez de la carpeta esperada | Las variables globales `CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG`/`_RELEASE` del `CMakeLists.txt` raíz inicializan la propiedad **específica de configuración** en cada target nuevo, y esa propiedad tiene prioridad sobre la genérica `RUNTIME_OUTPUT_DIRECTORY` fijada manualmente | Fija también las variantes por-configuración (`RUNTIME_OUTPUT_DIRECTORY_DEBUG`, `_RELEASE`, `_RELWITHDEBINFO`) en el `set_target_properties` de ese target, no solo la genérica (ver sección 6.13) |
| `multiple definition of 'main'` al enlazar `devkit_benchmarks` | Se usó `BENCHMARK_MAIN()` en un `.cpp` **y** se enlazó `benchmark::benchmark_main` a la vez — ambos proveen un `main()` | Elige solo una vía. `devkit` usa `benchmark::benchmark_main` en `target_link_libraries` (igual que `GTest::gtest_main`), así que ningún `.cpp` de `benchmark/` debe llevar `BENCHMARK_MAIN()` (ver sección 6.13) |
| `CMake Error: DEVKIT_BUILD_FUZZERS requiere Clang` al configurar con `-DDEVKIT_BUILD_FUZZERS=ON` | libFuzzer (`-fsanitize=fuzzer`) solo está integrado en Clang, no en GCC | Reconfigura con `./scripts/configure.sh debug clang` (ver sección 4.10) |

---

## 12. CI/CD: matriz de compiladores y release automático

### 12.1. Matriz de compiladores (GCC + Clang) en CI

El job `build-and-test-debug` de `.github/workflows/ci.yml` corre en paralelo con GCC y Clang, usando el mismo segundo argumento de `scripts/configure.sh` que usas localmente:

```yaml
  build-and-test-debug:
    needs: build-image
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        compiler: [gcc, clang]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with: { name: devkit-image, path: /tmp }
      - run: docker load -i /tmp/devkit-image.tar

      - name: Configure, build and test (${{ matrix.compiler }})
        run: |
          docker run --rm -v ${{ github.workspace }}:/home/dev/project \
            ${{ env.IMAGE_NAME }} bash -c '
              ./scripts/configure.sh debug ${{ matrix.compiler }} &&
              cmake --build --preset debug &&
              ctest --preset debug --output-on-failure
            '

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results-debug-${{ matrix.compiler }}
          path: temp/build/debug/Testing/
          retention-days: 7
```

`fail-fast: false` asegura que si Clang falla, sigues viendo el resultado completo de GCC (y viceversa) en vez de que se cancele el otro job de la matriz. No hace falta tocar `ci-success`: GitHub Actions ya espera a que **todas** las combinaciones de la matriz terminen antes de considerar satisfecho ese `needs`.

### 12.2. Release automático al hacer push de un tag

### Ruta: `.github/workflows/release.yml` (nuevo, separado de `ci.yml`)

```yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

env:
  IMAGE_NAME: devkit-fedora-env

jobs:
  build-release-binaries:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build dev image
        run: docker compose -f docker/docker-compose.yml build dev-env

      - name: Configure, build and test (Release)
        run: |
          docker run --rm -v ${{ github.workspace }}:/home/dev/project \
            ${{ env.IMAGE_NAME }} bash -c '
              ./scripts/configure.sh release &&
              cmake --build --preset release &&
              ctest --build-config Release --test-dir temp/build/release --output-on-failure
            '

      - name: Package binaries
        run: |
          mkdir -p release-artifacts
          tar -czf release-artifacts/devkit-${{ github.ref_name }}-linux-x86_64.tar.gz \
            -C bin/release .

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: release-artifacts/*.tar.gz
          generate_release_notes: true
          body_path: CHANGELOG.md
```

Se dispara automáticamente al empujar un tag `vX.Y.Z` — es el paso final del flujo de `scripts/release.sh` (sección 8.3):

```bash
./scripts/release.sh 0.3.0
# edita CHANGELOG.md, revisa, compila localmente si quieres verificar antes
git add -A && git commit -m "Bump version to 0.3.0"
git tag -a v0.3.0 -m "Release 0.3.0"
git push origin main --tags   # <-- dispara release.yml
```

El workflow compila en Release, corre los tests, empaqueta `bin/release/*` en `devkit-vX.Y.Z-linux-x86_64.tar.gz`, y crea automáticamente el Release en GitHub con notas autogeneradas más el contenido de `CHANGELOG.md`. Verifica el resultado en la pestaña **Actions** y el binario publicado en **Releases**.

---

## 13 VS-Code extensions

Most people use VS-Code even to develope inside a Docker container, .devcontainer/devcontainer.json holds the configuration to enable them inside Docker containers. It should be enough specially to eliminate false positive sintax errors.

---

## 14 .editconfig

En la raíz existe un .editconfig que indica a los IDE modernos la configuración de edición, es compatible con clang-format ya que este solo trata con los ficheros de C++ y talvez el usuario quiere una edición diferente para scripts de Python o Bash. Esto no es un formateador en tiempo real, simplemente configura por ejemplo al presionar tab el número de espacios con los que rellena. En VS Code se necesita la extension EditorConfig

---

## 15 .gitaatributes

Normaliza finales de línea y marca binarios explícitamente, para evitar diffs espurios y corrupción de binarios al clonar desde distintos SO.

---

## 16 .env

Recuerda añadirlo al .gitignore a diferencia del de Docker/.env y situarlo en la raíz del proyecto.

---

## 17 Pre-commits

En caso de querer verificar el formato, con pip se installa precommits, y si tu proyecto esta adminsitrado por git ejecutas:
```bash
pre-commit install
```

Y en cada commit comprobara con clang-format el formato del código y no dejara realizar commit si el codigo no esta según las especificaciones. Recuerda que no esta activado por defecto y debes ejecutar el comando tu mismo.

---

## 18 Clang-Tidy --fix

En caso de que quieras que clang-tidy arregle las sugerencias en tu codigo. En cmake/StaticAnylizer.cmake la segunda función en la que realiza el fix y se puede modificar sobre que directorios quiere que realice el fix, por defecto src/ y inc/

```bash
git status                                        # confirma que no hay cambios sin commitear
./scripts/configure.sh debug clang                # clang-tidy necesita compile_commands.json ya generado
cmake --preset debug -DENABLE_CLANG_TIDY=ON        # si no estaba ya activado (en debug lo está por defecto)
cmake --build temp/build/debug --target clang-tidy-fix
git diff
```

---

## 17. Referencia rápida de comandos

```bash
# Entorno
docker-compose -f docker/docker-compose.yml up -d
docker-compose -f docker/docker-compose.yml exec dev-env bash

# Debug
./scripts/configure.sh debug && cmake --build --preset debug && ctest --preset debug --output-on-failure

# Debug forzando compilador
rm -rf temp/build && ./scripts/configure.sh debug clang

# Debug como biblioteca compartida (.so)
rm -rf temp/build && ./scripts/configure.sh debug default shared

# Release
./scripts/configure.sh release && cmake --build --preset release && ctest --build-config Release --test-dir temp/build/release --output-on-failure

# Análisis / calidad
cmake --build temp/build/debug --target cppcheck
find inc src app test -name "*.hpp" -o -name "*.cpp" | xargs clang-format --dry-run --Werror

# Coverage
./scripts/configure.sh coverage && cmake --build temp/build/coverage && ctest --test-dir temp/build/coverage && cmake --build temp/build/coverage --target coverage

# Valgrind
./scripts/configure.sh valgrind && cmake --build temp/build/valgrind && cmake --build temp/build/valgrind --target memcheck

# Documentación
cmake --preset debug -DDEVKIT_BUILD_DOCS=ON && cmake --build temp/build/debug --target docs

# Benchmarks (medir siempre en Release)
./scripts/configure.sh release && cmake --preset release -DDEVKIT_BUILD_BENCHMARKS=ON && cmake --build --preset release && ./bin/benchmark/devkit_benchmarks

# Ejecutar el binario
./bin/debug/devkit

# Fuzzing (requiere Clang)
./scripts/configure.sh debug clang && cmake --preset debug -DDEVKIT_BUILD_FUZZERS=ON && cmake --build --preset debug && mkdir -p fuzz/corpus/shape_printer && ./bin/fuzz/fuzz_shape_printer -max_total_time=60 fuzz/corpus/shape_printer

# Publicar un release (dispara release.yml en CI)
./scripts/release.sh 0.3.0 && git add -A && git commit -m "Bump version to 0.3.0" && git tag -a v0.3.0 -m "Release 0.3.0" && git push origin main --tags
```
