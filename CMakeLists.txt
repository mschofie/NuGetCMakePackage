#[[====================================================================================================================
====================================================================================================================]]#
include_guard()

define_property(VARIABLE
    PROPERTY NUGET_PACKAGE_ROOT_PATH
    BRIEF_DOCS "The root path where NuGet packages will be installed."
    FULL_DOCS [=[
NuGet packages will be downloaded to `NUGET_PACKAGE_ROOT_PATH`. If `NUGET_PACKAGE_ROOT_PATH` is not set, then packages
will be downloaded to `${CMAKE_BINARY_DIR}/__nuget`.

Note: Since `CMAKE_BINARY_DIR` is platform specific, the default download location will change by platform, resulting
in NuGet packages being downloaded once for each platform that is built. Setting `NUGET_PACKAGE_ROOT_PATH` to a
platform-independent path (e.g. relative to the root of the repository) will allow NuGet packages to be downloaded
once for all platforms.
]=])

define_property(VARIABLE
    PROPERTY NUGET_TOOLS_PATH
    BRIEF_DOCS "The path where the NuGet executable will be installed if it cannot be found."
    FULL_DOCS [=[
If neeeded, the NuGet executable will be downloaded to `NUGET_TOOLS_PATH`. If `NUGET_TOOLS_PATH` is not set, then it
will be downloaded to `${CMAKE_BINARY_DIR}/__tools`.

Note: Since `CMAKE_BINARY_DIR` is platform specific, the default download location will change by platform, resulting
in NuGet being downloaded once for each platform that is built. Setting `NUGET_TOOLS_PATH` to a platform-independent
path (e.g. relative to the root of the repository) will allow NuGet to be downloaded once for all platforms.
]=])

define_property(TARGET
    PROPERTY NUGET_VERSION
    BRIEF_DOCS "The version of the NuGet package."
)

define_property(TARGET
    PROPERTY NUGET_LOCATION
    BRIEF_DOCS "The location where the NuGet package is installed."
)

#[[====================================================================================================================
    ensure_nuget
    ------------

    Ensures that NuGet is available and the NUGET_PATH variables is set in the cache. The following steps will be
    taken:

        1. If `NUGET_PATH` is set, then that value will be used.
        2. If NuGet is found through `find_program`, that path will be used.
        3. NuGet will be downloaded - specified by `NUGET_VERSION` and `NUGET_HASH` - into the `NUGET_TOOLS_PATH`
           and `NUGET_PATH` will be set to the download location. If `NUGET_TOOLS_PATH` is not set, then it will
           default to `${CMAKE_BINARY_DIR}/__tools`.
====================================================================================================================]]#
function(ensure_nuget)
    find_program(NUGET_PATH
        NAMES nuget nuget.exe
    )

    # If NuGet isn't found, download it.
    #
    # NuGet.exe will be downloaded to `NUGET_TOOLS_PATH`. If `NUGET_TOOLS_PATH` is not set then it will be downloaded to '${CMAKE_BINARY_DIR}/__tools'.
    if(NUGET_PATH STREQUAL "NUGET_PATH-NOTFOUND")
        if(NOT NUGET_VERSION)
            set(NUGET_VERSION "6.14.0")
            set(NUGET_HASH "SHA256=92dbed160ddee0f64b901e907439e021211b428e57c089ecc12fc38dcc4bd9a5")
        else()
            if(NOT NUGET_HASH)
                message(FATAL_ERROR "NUGET_VERSION is set to ${NUGET_VERSION}. NUGET_HASH must be set if NUGET_VERSION is set.")
            endif()
        endif()

        if(NOT NUGET_TOOLS_PATH)
            set(NUGET_TOOLS_PATH "${CMAKE_BINARY_DIR}/__tools")
        endif()

        set(NUGET_PATH "${NUGET_TOOLS_PATH}/nuget.exe" CACHE FILEPATH "The location of 'nuget.exe'" FORCE)

        file(DOWNLOAD
            "https://dist.nuget.org/win-x86-commandline/v${NUGET_VERSION}/nuget.exe"
            ${NUGET_PATH}
            EXPECTED_HASH ${NUGET_HASH}
        )
    endif()
endfunction()

#[[====================================================================================================================
    install_nuget_package
    ---------------------

    Downloads a NuGet package.

        install_nuget_package(
            <package name>
            <package version>
            <variable name>
            [PRERELEASE <ON|OFF>]
            [FRAMEWORK <framework>]
            [CONFIG_FILE <config file path>]
            [PACKAGESAVEMODE <nuspec|nupkg>]
            [DEPENDENCYVERSION <Lowest|HighestPatch|HighestMinor|Highest|Ignore>]
        )

    The packages will be downloaded to `NUGET_PACKAGE_ROOT_PATH`. If `NUGET_PACKAGE_ROOT_PATH` is not set, then
    packages will be downloaded to `${CMAKE_BINARY_DIR}/__nuget`.
====================================================================================================================]]#
function(install_nuget_package NUGET_PACKAGE_NAME NUGET_PACKAGE_VERSION VARIABLE_NAME)
    set(OPTIONS)
    set(ONE_VALUE_KEYWORDS CONFIG_FILE FRAMEWORK PRERELEASE PACKAGESAVEMODE DEPENDENCYVERSION)
    set(MULTI_VALUE_KEYWORDS)

    cmake_parse_arguments(PARSE_ARGV 3 NUGET "${OPTIONS}" "${ONE_VALUE_KEYWORDS}" "${MULTI_VALUE_KEYWORDS}")

    if(NOT NUGET_PACKAGE_ROOT_PATH)
        set(NUGET_PACKAGE_ROOT_PATH ${CMAKE_BINARY_DIR}/__nuget)
    endif()

    set(NUGET_PACKAGE_PATH "${NUGET_PACKAGE_ROOT_PATH}/${NUGET_PACKAGE_NAME}.${NUGET_PACKAGE_VERSION}")

    if(NOT EXISTS "${NUGET_PACKAGE_PATH}")
        ensure_nuget()

        set(NUGET_COMMAND ${NUGET_PATH} install ${NUGET_PACKAGE_NAME})

        list(APPEND NUGET_COMMAND -OutputDirectory ${NUGET_PACKAGE_ROOT_PATH})
        list(APPEND NUGET_COMMAND -Version ${NUGET_PACKAGE_VERSION})

        if(NUGET_PRERELEASE)
            list(APPEND NUGET_COMMAND -Prerelease)
        endif()

        if(DEFINED NUGET_CONFIG_FILE)
            list(APPEND NUGET_COMMAND -ConfigFile ${NUGET_CONFIG_FILE})
        endif()

        if(DEFINED NUGET_FRAMEWORK)
            list(APPEND NUGET_COMMAND -Framework ${NUGET_FRAMEWORK})
        endif()

        if(DEFINED NUGET_PACKAGESAVEMODE)
            list(APPEND NUGET_COMMAND -PackageSaveMode ${NUGET_PACKAGESAVEMODE})
        endif()

        if(DEFINED NUGET_DEPENDENCYVERSION)
            list(APPEND NUGET_COMMAND -DependencyVersion ${NUGET_DEPENDENCYVERSION})
        endif()

        message(STATUS "Downloading ${NUGET_PACKAGE_NAME} ${NUGET_PACKAGE_VERSION}")
        message(VERBOSE "install_nuget_package: NUGET_COMMAND = ${NUGET_COMMAND}")

        execute_process(
            COMMAND ${NUGET_COMMAND}
            OUTPUT_VARIABLE NUGET_OUTPUT
            ERROR_VARIABLE NUGET_ERROR
            RESULT_VARIABLE NUGET_RESULT
        )

        message(VERBOSE "install_nuget_package: NUGET_OUTPUT = ${NUGET_OUTPUT}")
        if(NOT (NUGET_RESULT STREQUAL 0))
            message(FATAL_ERROR "install_nuget_package: Install failed with: ${NUGET_ERROR}")
        endif()
    endif()

    set(${VARIABLE_NAME} "${NUGET_PACKAGE_PATH}" PARENT_SCOPE)
endfunction()

#[[====================================================================================================================
    add_nuget_library
    -----------------

    Downloads a NuGet package and uses CMake scripts within the package to provide a description of the NuGet package.
    A new CMake target will be created with the name of the NuGet package, which can then be referenced by consumers.

        add_nuget_library(
            <package name>
            <package version>
            [PRERELEASE <ON|OFF>]
            [FRAMEWORK <framework>]
            [CONFIG_FILE <config file path>]
            [DEPENDENCYVERSION <Lowest|HighestPatch|HighestMinor|Highest|Ignore>]
        )

    The packages will be downloaded to `NUGET_PACKAGE_ROOT_PATH`. If `NUGET_PACKAGE_ROOT_PATH` is not set, then
    packages will be downloaded to `${CMAKE_BINARY_DIR}/__nuget`.


====================================================================================================================]]#
function(add_nuget_library PACKAGE_NAME PACKAGE_VERSION)
    message(VERBOSE "add_nuget_library: PACKAGE_NAME: ${PACKAGE_NAME}")
    message(VERBOSE "add_nuget_library: PACKAGE_VERSION: ${PACKAGE_VERSION}")
    if(NOT (PACKAGE_VERSION MATCHES [=[^([0-9]+)\.([0-9]+)\.([0-9]+)(\.([0-9]+))?(-.*)?$]=]))
        message(FATAL_ERROR "add_nuget_library: Package version must be specified, and must match semantic versioning: ${PACKAGE_VERSION}")
    endif()

    if(TARGET ${PACKAGE_NAME})
        # Check the original version and if it's the same, just return.
        get_target_property(EXISTING_VERSION ${PACKAGE_NAME} NUGET_VERSION)
        if(EXISTING_VERSION STREQUAL PACKAGE_VERSION)
            message(VERBOSE "add_nuget_library: The package '${PACKAGE_NAME}' version '${PACKAGE_VERSION}' has already been added.")
            set("${PACKAGE_NAME}_FOUND" TRUE PARENT_SCOPE)
            return()
        endif()
        message(FATAL_ERROR "add_nuget_library: The package '${PACKAGE_NAME}' has already been added.")
    endif()

    # Install the NuGet package.
    install_nuget_package(${PACKAGE_NAME} ${PACKAGE_VERSION} NUGET_LOCATION
        PRERELEASE ON
        PACKAGESAVEMODE nuspec
    )
    message(VERBOSE "add_nuget_library: NUGET_LOCATION: ${NUGET_LOCATION}")

    # TODO: Perform a 'bottom-up' walk of the package dependencies to ensure all dependencies are installed.
    # This requires XML parsing. Which is hard.
    # packages/dependencies/dependency
    # packages/dependencies/group[@targetFramework='native']/dependency
    #
    # ([xml](Get-Content ${NUGET_LOCATION}\${PACKAGE_NAME}.nuspec)).package.metadata.dependencies.dependency

    # Build and set the NUGET_PROPERTY_NAME. This must be set before include'ing the package's CMake configuration file.
    #   1. replace '.' and '-' with '_' to make it a valid CMake variable name
    #   2. convert to uppercase to follow CMake variable naming conventions
    #   3. prepend 'NUGET_' to avoid collisions with other variables
    set(NUGET_PROPERTY_NAME ${PACKAGE_NAME})
    string(REPLACE "." "_" NUGET_PROPERTY_NAME ${NUGET_PROPERTY_NAME})
    string(REPLACE "-" "_" NUGET_PROPERTY_NAME ${NUGET_PROPERTY_NAME})
    string(TOUPPER ${NUGET_PROPERTY_NAME} NUGET_PROPERTY_NAME)
    set(NUGET_PROPERTY_NAME "NUGET_${NUGET_PROPERTY_NAME}")
    set(${NUGET_PROPERTY_NAME} ${NUGET_LOCATION})

    # Include the package's CMake configuration file if it exists.
    # If a CMake configuration file isn't found in the package, see if a 'fallback' CMake configuration file exists in
    # the current function list directory, and use that instead.
    string(TOLOWER ${PACKAGE_NAME} PACKAGE_NAME_LOWER)
    set(PROBE_PATHS
        "${NUGET_LOCATION}/build/cmake/${PACKAGE_NAME_LOWER}-config.cmake"
        "${NUGET_LOCATION}/build/native/${PACKAGE_NAME_LOWER}.cmake"
        "${NUGET_LOCATION}/build/${PACKAGE_NAME_LOWER}.cmake"
        "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/build/cmake/${PACKAGE_NAME_LOWER}-config.cmake"
    )

    foreach(PROBE_PATH ${PROBE_PATHS})
        if(NOT (EXISTS "${PROBE_PATH}"))
            continue()
        endif()

        message(VERBOSE "add_nuget_library: include: ${PROBE_PATH}")
        include("${PROBE_PATH}")
        break()
    endforeach()

    if(NOT (TARGET ${PACKAGE_NAME}))
        add_library(${PACKAGE_NAME} INTERFACE)
    endif()

    set_target_properties(${PACKAGE_NAME}
        PROPERTIES
            NUGET_VERSION ${PACKAGE_VERSION}
            NUGET_LOCATION ${NUGET_LOCATION}
            FOLDER NuGet
    )

    set("${PACKAGE_NAME}_FOUND" TRUE PARENT_SCOPE)
endfunction()
