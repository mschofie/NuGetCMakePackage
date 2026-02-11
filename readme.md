# Microsoft NuGet Support for CMake

This repository contains common infrastructure for using NuGet packages from within CMake.

> [!IMPORTANT]
> This is an experimental repository! It is exploring possibilities for NuGet and CMake integration. Please try things
> out and provide feedback - either good or bad! File issues or open discussions and help influence the direction.

## Usage

This repository is intended to be consumed through [CMake's FetchContent package][cmake-fetchcontent]. Consumers should add a call to [`FetchContent_Declare`][fetchcontent_declare] to declare the content details:

```cmake
FetchContent_Declare(
    NuGetCMakePackage
    GIT_REPOSITORY https://github.com/mschofie/NuGetCMakePackage
    GIT_TAG 0123456789abcdef0123456789abcdef01234567
)
```

where `GIT_REPOSITORY` specifies this repository, and `GIT_TAG` is the commit hash for the version to be used. Note that `GIT_TAG` does not need to be specified as a commit hash, but using a hash is a best practice for secure and deterministic builds.

Having declared the content, make a call to [`FetchContent_MakeAvailable`][fetchcontent_makeavailable] to instruct CMake to download and process the content:

```cmake
FetchContent_MakeAvailable(NuGetCMakePackage)
```

After calling `FetchContent_MakeAvailable` the `add_nuget_packages` function is available to install NuGet packages.

### Using 'add_nuget_packages'

`add_nuget_packages` will download NuGet packages - using [the 'NuNuGet' tooling][nunuget_tooling] - into the Global Packages Path and then look for CMake scripts within the NuGet making those scripts findable through CMake's [`find_package`][cmake-find_package]. See [the comments on `add_nuget_packages`](./CMakeLists.txt) for more details on the heuristics that are applied. After calling `add_nuget_packages`, call `find_package` to include the package in the build. For example:

```cmake
add_nuget_packages(
    PACKAGES
        Microsoft.Windows.ImplementationLibrary 1.0.250325.1
    CONFIG_FILE ./nuget.config
    LOCK_FILE ./packages.lock.json
)
```

```cmake
find_package(Microsoft.Windows.ImplementationLibrary CONFIG REQUIRED)
```

```cmake
target_link_libraries(SomeTarget
    PRIVATE
        Microsoft.Windows.ImplementationLibrary
)
```

### End-to-end flow (implementation sequence)

See the full sequence diagram in [documentation/end-to-end-sequence.md](./documentation/end-to-end-sequence.md).

## Configuration

The behavior of this package can be configured with the following CMake variables:

* `NUGET_TOOLS_PATH` - If needed, the NuNuGet tooling will be downloaded to `NUGET_TOOLS_PATH`. If `NUGET_TOOLS_PATH` is not set, then it will be downloaded to `${CMAKE_BINARY_DIR}/__tools`.

    Note: Since `CMAKE_BINARY_DIR` is platform specific, the default download location will change by platform, resulting in NuGet being downloaded once for each platform that is built. Setting `NUGET_TOOLS_PATH` to a platform-independent path (e.g. relative to the root of the repository) will allow NuNuGet to be downloaded once for all platforms.

[cmake-fetchcontent]: https://cmake.org/cmake/help/latest/module/FetchContent.html
[cmake-find_package]: https://cmake.org/cmake/help/latest/command/find_package.html
[fetchcontent_declare]: https://cmake.org/cmake/help/latest/module/FetchContent.html#command:fetchcontent_declare
[fetchcontent_makeavailable]: https://cmake.org/cmake/help/latest/module/FetchContent.html#command:fetchcontent_makeavailable
[nunuget_tooling]: https://github.com/mschofie/NuNuGet
