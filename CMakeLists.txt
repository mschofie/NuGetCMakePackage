#[[====================================================================================================================
====================================================================================================================]]#

include_guard()

# Check for minimum CMake version. Avoid using `cmake_minimum_required`, which will reset policies if this file is
# included by a project that has already specified a minimum CMake version.
if(CMAKE_VERSION VERSION_LESS 3.31)
    message(FATAL_ERROR "NuGetCMakePackage requires at least CMake 3.31, but CMake ${CMAKE_VERSION} is in use.")
endif()

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
If needed, the NuGet executable will be downloaded to `NUGET_TOOLS_PATH`. If `NUGET_TOOLS_PATH` is not set, then it
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
    if(NOT NUGET_PATH)
        if(NOT NUGET_VERSION)
            set(NUGET_VERSION "7.3.0")
            set(NUGET_HASH "SHA256=39b6309e76c832e4de2ac7f86da9a8afaa12bc5b4307ea335e9d69e2d6d1a94a")
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
    block(SCOPE_FOR POLICIES)
        cmake_policy(SET CMP0174 NEW) # cmake_parse_arguments(PARSE_ARGV) defines a variable for an empty string after a single-value keyword.

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

            if(NUGET_CONFIG_FILE)
                list(APPEND NUGET_COMMAND -ConfigFile ${NUGET_CONFIG_FILE})
            endif()

            if(NUGET_FRAMEWORK)
                list(APPEND NUGET_COMMAND -Framework ${NUGET_FRAMEWORK})
            endif()

            if(NUGET_PACKAGESAVEMODE)
                list(APPEND NUGET_COMMAND -PackageSaveMode ${NUGET_PACKAGESAVEMODE})
            endif()

            if(NUGET_DEPENDENCYVERSION)
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
    endblock()
endfunction()

#[[====================================================================================================================
    add_nuget_packages
    ------------------

    Adds the specified NuGet packages to the build. `add_nuget_packages` will download the specified packages - and
    necessary dependencies - and make the package findable through `find_package`.

        add_nuget_packages(
            <PACKAGES
                [<package name> <package version>]*
            >
            [CONFIG_FILE <config file path>]
            [FRAMEWORK <framework>]
            [DEPENDENCYVERSION <Lowest|HighestPatch|HighestMinor|Highest|Ignore>]
            [PACKAGESAVEMODE <nuspec|nupkg>]
            [PRERELEASE <ON|OFF>]
        )

    After calling 'add_nuget_packages' the following GLOBAL properties will be set:

        * NUGET_VERSION-<canonical package name> - The version of the NuGet that was installed.
        * NUGET_LOCATION-<canonical package name> - The folder path to the root of the NuGet package.

    In the above properties <canonical package name> is the original package name converted to uppercase, and any
    '.' and '-' characters converted to '_' characters.

    If the NuGet package is found to contain a CMake script, then a variable will be set - in the parent scope -
    for `find_package` to find and include the CMake script using the name of the package.

    For example, if the following call is made:

        ```
        add_nuget_packages(
            PACKAGES
                Microsoft.Windows.ImplementationLibrary 1.0.240803.1
        )
        ```

    Then the following global properties will be set:

        * NUGET_VERSION-MICROSOFT_WINDOWS_IMPLEMENTATIONLIBRARY - 1.0.240803.1
        * NUGET_LOCATION-MICROSOFT_WINDOWS_IMPLEMENTATIONLIBRARY - <path to NuGet root>

    And the following variables will be set in the parent scope:

        * '${PACKAGE_NAME_UPPER}_ROOT' will point to the NuGet package location, if CMP0074 is NEW and CMP0144 is NEW
        * '${PACKAGE_NAME}_ROOT' will point to the NuGet package location, if CMP0074 is NEW and CMP0144 is OLD
        * '${PACKAGE_NAME}_DIR' will point to the NuGet package location, if CMP0074 is OLD

====================================================================================================================]]#
function(add_nuget_packages)
    block(SCOPE_FOR POLICIES)
        cmake_policy(SET CMP0174 NEW) # cmake_parse_arguments(PARSE_ARGV) defines a variable for an empty string after a single-value keyword.

        set(OPTIONS)
        set(ONE_VALUE_KEYWORDS CONFIG_FILE DEPENDENCYVERSION PACKAGESAVEMODE PRERELEASE)
        set(MULTI_VALUE_KEYWORDS PACKAGES)

        cmake_parse_arguments(PARSE_ARGV 0 ADD_NUGET "${OPTIONS}" "${ONE_VALUE_KEYWORDS}" "${MULTI_VALUE_KEYWORDS}")

        # Get policy CMP0074:
        #   if OLD, the '${PACKAGE_NAME}_DIR' should point to the NuGet package location
        #   if NEW, the '${PACKAGE_NAME}_ROOT' should point to the NuGet package location
        cmake_policy(GET CMP0074 POLICY_CMP0074)

        # Get policy CMP0144:
        #   if OLD, the '${PACKAGE_NAME}_ROOT' should point to the NuGet package location
        #   if NEW, the '${PACKAGE_NAME_UPPER}_ROOT' should point to the NuGet package location
        cmake_policy(GET CMP0144 POLICY_CMP0144)

        # Ensure that 'ADD_NUGET_PACKAGESAVEMODE' has - at least 'nuspec'
        if (ADD_NUGET_PACKAGESAVEMODE STREQUAL "")
            set(ADD_NUGET_PACKAGESAVEMODE nuspec)
        elseif(NOT (ADD_NUGET_PACKAGESAVEMODE MATCHES "nuspec"))
            set(ADD_NUGET_PACKAGESAVEMODE "${ADD_NUGET_PACKAGESAVEMODE};nuspec")
        endif()

        # Enumerate the packages and 'install' each one.
        while(ADD_NUGET_PACKAGES)
            list(POP_FRONT ADD_NUGET_PACKAGES PACKAGE_NAME)
            list(POP_FRONT ADD_NUGET_PACKAGES PACKAGE_VERSION)

            if((PACKAGE_NAME STREQUAL "") OR (PACKAGE_VERSION STREQUAL ""))
                message(FATAL_ERROR "add_nuget_packages: 'PACKAGES' must be passed valid NuGet name/version pairs.")
            endif()

            # Build 'PACKAGE_NAME_PROPERTY' - the CMake-property friendly form of PACKAGE_NAME.
            #   1. convert to uppercase to follow CMake variable naming conventions
            #   2. replace '.' and '-' with '_' to make it a valid CMake variable name
            string(TOUPPER ${PACKAGE_NAME} PACKAGE_NAME_UPPER)
            string(TOLOWER ${PACKAGE_NAME} PACKAGE_NAME_LOWER)
            string(REPLACE "." "_" PACKAGE_NAME_PROPERTY ${PACKAGE_NAME_UPPER})
            string(REPLACE "-" "_" PACKAGE_NAME_PROPERTY ${PACKAGE_NAME_PROPERTY})

            get_property(EXISTING_VERSION GLOBAL PROPERTY "NUGET_VERSION-${PACKAGE_NAME_PROPERTY}")
            if(EXISTING_VERSION)
                # The NuGet has already been added. If the version matches, just continue.
                if(EXISTING_VERSION STREQUAL PACKAGE_VERSION)
                    message(VERBOSE "add_nuget_packages: The package '${PACKAGE_NAME}' version '${PACKAGE_VERSION}' has already been added.")
                    set("${PACKAGE_NAME}_FOUND" TRUE PARENT_SCOPE)
                    continue()
                endif()
                message(FATAL_ERROR "add_nuget_packages: The package '${PACKAGE_NAME}' has already been added with version ${EXISTING_VERSION} - unable to add version ${PACKAGE_VERSION}.")
            endif()

            install_nuget_package(${PACKAGE_NAME} ${PACKAGE_VERSION} NUGET_LOCATION
                PRERELEASE ${ADD_NUGET_PRERELEASE}
                FRAMEWORK ${ADD_NUGET_FRAMEWORK}
                CONFIG_FILE ${ADD_NUGET_CONFIG_FILE}
                PACKAGESAVEMODE ${ADD_NUGET_PACKAGESAVEMODE}
                DEPENDENCYVERSION ${ADD_NUGET_DEPENDENCYVERSION}
            )

            # Look for package details in the NuGet - if they exist, set the relevant property to reference it
            # so that find_package can find it.
            set(PROBE_PATHS
                "${NUGET_LOCATION}/build/cmake/${PACKAGE_NAME_LOWER}-config.cmake"
                "${NUGET_LOCATION}/build/native/${PACKAGE_NAME_LOWER}.cmake"
                "${NUGET_LOCATION}/build/${PACKAGE_NAME_LOWER}.cmake"
                "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/overlay/${PACKAGE_NAME_LOWER}/${PACKAGE_NAME_LOWER}-config.cmake"
            )

            foreach(PROBE_PATH ${PROBE_PATHS})
                if(NOT (EXISTS "${PROBE_PATH}"))
                    continue()
                endif()

                message(VERBOSE "add_nuget_library: ${PROBE_PATH}")
                set(PROBE_FOLDER "${PROBE_PATH}/..")
                cmake_path(NORMAL_PATH PROBE_FOLDER)

                if(POLICY_CMP0074 STREQUAL "NEW")
                    if(POLICY_CMP0144 STREQUAL "NEW")
                        set(${PACKAGE_NAME_UPPER}_ROOT ${PROBE_FOLDER} PARENT_SCOPE)
                    else()
                        set(${PACKAGE_NAME}_ROOT ${PROBE_FOLDER} PARENT_SCOPE)
                    endif()
                else()
                    set(${PACKAGE_NAME}_DIR ${PROBE_FOLDER} PARENT_SCOPE)
                endif()

                set_property(GLOBAL PROPERTY "NUGET_VERSION-${PACKAGE_NAME_PROPERTY}" ${PACKAGE_VERSION})
                set_property(GLOBAL PROPERTY "NUGET_LOCATION-${PACKAGE_NAME_PROPERTY}" ${NUGET_LOCATION})
                break()
            endforeach()
        endwhile()
    endblock()
endfunction()
