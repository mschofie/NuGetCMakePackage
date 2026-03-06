#[[====================================================================================================================
====================================================================================================================]]#

include_guard()

# Check for minimum CMake version. Avoid using `cmake_minimum_required`, which will reset policies if this file is
# included by a project that has already specified a minimum CMake version.
if(CMAKE_VERSION VERSION_LESS 3.31)
    message(FATAL_ERROR "NuGetCMakePackage requires at least CMake 3.31, but CMake ${CMAKE_VERSION} is in use.")
endif()

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
                "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/build/cmake/${PACKAGE_NAME_LOWER}-config.cmake"
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
