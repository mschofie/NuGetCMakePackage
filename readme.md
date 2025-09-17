# Microsoft NuGet Support for CMake

This repository contains common infrastructure for using NuGet packages from within CMake.

## Usage

This repository is intended to be consumed through [CMake's FetchContent package][cmake-fetch-content]. Consumers should add a call to [`FetchContent_Declare`][fetchcontent_declare] to declare the content details:

```cmake
FetchContent_Declare(
    CMakeNuGetPackage
    GIT_REPOSITORY https://github.com/mschofie/NuGetCMakePackage
    GIT_TAG 0a8e48e316df648e0e369e2f8b9957e63113b9be
)
```

where `GIT_REPOSITORY` specifies this repository, and `GIT_TAG` is the commit hash for the version to be used. Note that `GIT_TAG` does not need to be specified as a commit hash, but using a hash is a best practice for secure and deterministic builds.

Having declared the content, make a call to [`FetchContent_MakeAvailable`][fetchcontent_makeavailable] to instruct CMake to download and process the content:

```cmake
FetchContent_MakeAvailable(CMakeNuGetPackage)
```

After calling `FetchContent_MakeAvailable` two main functions are available for leveraging NuGet packages: `install_nuget_package` and `add_nuget_library`.

### Using 'install_nuget_package'

`install_nuget_package` downloads a given NuGet package and returns a path to the downloaded location. For example:

```cmake
install_nuget_package(Microsoft.Windows.ImplementationLibrary 1.0.250325.1 NUGET_MICROSOFT_WINDOWS_IMPLEMENTATIONLIBRARY)
```

will download the 'Microsoft.Windows.ImplementationLibrary' NuGet package, version 1.0.250325.1 and set `NUGET_MICROSOFT_WINDOWS_IMPLEMENTATIONLIBRARY` (in the calling scope) to the location of the root of the package.

### Using 'add_nuget_library'

`add_nuget_library` will download a NuGet package - using `install_nuget_package` - and then look for CMake scripts within the NuGet package to parse, providing a description of the package. See [the comments on `add_nuget_library`](./CMakeLists.txt) for more details on the heuristics that are applied. After calling `add_nuget_library` a CMake target will be introduced that represents the NuGet package, and can be referenced by consumers. For example:

```cmake
add_nuget_library(Microsoft.Windows.ImplementationLibrary 1.0.250325.1)
```

```cmake
target_link_libraries(SomeTarget
    PRIVATE
        Microsoft.Windows.ImplementationLibrary
)
```

## Configuration

The behavior of this package can be configured with the following CMake variables:

* `NUGET_PACKAGE_ROOT_PATH` - NuGet packages will be downloaded to `NUGET_PACKAGE_ROOT_PATH`. If `NUGET_PACKAGE_ROOT_PATH` is not set, then packages will be downloaded to `${CMAKE_BINARY_DIR}/__nuget`.

    Note: Since `CMAKE_BINARY_DIR` is platform specific, the default download location will change by platform, resulting in NuGet packages being downloaded once for each platform that is built. Setting `NUGET_PACKAGE_ROOT_PATH` to a platform-independent path (e.g. relative to the root of the repository) will allow NuGet packages to be downloaded once for all platforms.

* `NUGET_TOOLS_PATH` - If neeeded, the NuGet executable will be downloaded to `NUGET_TOOLS_PATH`. If `NUGET_TOOLS_PATH` is not set, then it will be downloaded to `${CMAKE_BINARY_DIR}/__tools`.

    Note: Since `CMAKE_BINARY_DIR` is platform specific, the default download location will change by platform, resulting in NuGet being downloaded once for each platform that is built. Setting `NUGET_TOOLS_PATH` to a platform-independent path (e.g. relative to the root of the repository) will allow NuGet to be downloaded once for all platforms.

[cmake-fetch-content]: https://cmake.org/cmake/help/latest/module/FetchContent.html
[fetchcontent_declare]: https://cmake.org/cmake/help/latest/module/FetchContent.html#command:fetchcontent_declare
[fetchcontent_makeavailable]: https://cmake.org/cmake/help/latest/module/FetchContent.html#command:fetchcontent_makeavailable
