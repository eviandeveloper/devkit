# Profesional C++ Template (STILL IN PROGRESS)

## WAIT UNTIL VERSION 1.0.0 (ALREADY PUBLIC FOR THE GITHUB ACTIONS)

Configuring a C++ project is basically TORTURE for new users, especially the fact that nowadays every professional project, regardless of the language, uses a bunch of tools developed by different people, making it harder to synchronize, find what you need in their documentation... This template might be overkill for people learning C++ or those who know it but at the same time are not really familiarized with the ecosystem that surrounds it. Firstly, I recommend getting familiarized with some of the tools before combining all of them, especially the compiler's options, CMake, Conan, and Docker. At the same time I want to state that this template doesn't need to be the perfect template but a set of good practices to make your code reproducible everywhere and let other projects/people use your library. Feel free to do whatever the MIT license allows you to do.

# IMPORTANT

For now there is only support for Linux environments due to a lack of knowledge of Windows systems for development since I would like to offer the best practices, but some of the configurations can be used in both environments. Also, some users might want to use system calls from Linux, making it harder to be portable.

There is only support for GitHub Actions or fetching content from CMake in case somebody wanted support for Codeberg, but it shouldn't be that difficult to add it or migrate.

Since Modules support is still buggy in GCC and CLang it wont be supported in this configuration from now

## Software development best practices taken in consideration

Agnostic to programming language best practices enforced in software development:
- Generate a documentation website (we will use Doxygen and Graphviz)
- Coverage website based on the tests.
- Add a suite of test cases to verify that our does the expected
- Automatize running tests on watch
- Apply fuzzing techniques to find bugs
- Have a Test / Release / Debug configuration
- Use Docker to make the project reproducible and easy to set up almost out of the box (still needs to be polished due to the use of Fedora as the base image).
- In this case since the project is about C++, we will compile the project with GCC and Clang as a double check.
- Use of static analyzers, sanitizers, and debuggers to hopefully reach a bug-free state in our library.
- Speed up the compiling process.
- Use of Git for versioning.
- Force a format style across the developers; here we use the Google style guide.
- Delegate installing third-party libraries to a package manager.
- Delegate building process to a building system.
- Separate interface (.hpp) from implementation (.cpp)
- Use continuous integration (CI) to trigger automated tests/processes once we have merged our changes into the main repository, in this case GitHub. <<<IMPORTANT>>> In GitHub it is only free if your repository is public; otherwise you have limited time and you might have to pay.
- Some people might care about the performance of their libraries, so we will have a benchmark for our C++ code.
- Pre-commit to check code format.
- Hardening the binaries.
- .env file to store envirioment variables.

## C++ project configuration problems

The common problems/configurations in a C++ project that we want to take into consideration:
- Set up CMake to automate our building/compiling process.
- Set up Conan to download third-party libraries (we will use it only for those libraries that our code, tests, and benchmark need; the rest are installed via the package manager of the base image OS repositories).
- Set up the standard that we want to use.
- Setup compiler flags.
- Set up static analyzers like clang-tidy or sanitizers like valgrind to check memory leaks.
- Set up an intelligence that doesn't panic when it includes third-party libraries or the STL.
- Setup a fuzzer (libFuzzer from Clang).
- Set up Ninja to speed up the building process.
- Set up ccache to avoid recompiling.
- Install our library via Cpack

## Dependecies

All you need is Docker and Docker-Compose, usually they even come together through the installation process. The exact version used:
- Docker version 29.6.2, build 1.fc44
- Docker Compose version 5.3.1

## Packages installed inside Docker container

Installed via the DNF package manager are those packages that are only meant for development and not inherently a dependency of our library:

- clang
- clang-tools-extra
- gcc
- libasan
- libtsan
- cmake
- ninja-build
- ccache
- pkgconf-pkg-config
- python3
- python3-pip
- git
- findutils
- make
- dpkg
- diffutils
- graphviz
- gdb
- lldb
- strace
- ltrace
- perf
- valgrind
- doxygen
- cppcheck
- include-what-you-use
- entr

## Packages installed through Python inside the container

- conan
- gcovr: installed this way because it is the recommended way.

You could even create a Python env if needed to install these packages.

## Packages installed through Conan package manager

- fmt
- gtest
- benchmark

## Technical notes

Access to notes/README.md to understand the configuration and use it.

## Recomendations

Any upgrade/recommendation is susceptible to being accepted but always with education.
