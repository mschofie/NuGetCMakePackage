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
    BRIEF_DOCS "The path where the NuNuGet executable will be installed if it cannot be found."
    FULL_DOCS [=[
If needed, the NuNuGet executable will be downloaded to `NUGET_TOOLS_PATH`. If `NUGET_TOOLS_PATH` is not set, then it
will be downloaded to `${CMAKE_BINARY_DIR}/__tools`.

Note: Since `CMAKE_BINARY_DIR` is platform specific, the default download location will change by platform, resulting
in NuGet being downloaded once for each platform that is built. Setting `NUGET_TOOLS_PATH` to a platform-independent
path (e.g. relative to the root of the repository) will allow NuNuGet to be downloaded once for all platforms.
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
    ensure_nunuget
    --------------

    Ensures that NuNuGet is available and the NUNUGET_PATH variables is set in the cache. The following steps will be
    taken:

        1. If `NUNUGET_PATH` is set, then that value will be used.
        2. If NuNuGet is found through `find_program`, that path will be used.
        3. NuNuGet will be downloaded into the `NUGET_TOOLS_PATH` and `NUNUGET_PATH` will be set to the download
        location. If `NUGET_TOOLS_PATH` is not set, then it will default to `${CMAKE_BINARY_DIR}/__tools`.
====================================================================================================================]]#
function(ensure_nunuget)
    set(NUNUGET_NAME "NuNuGet")
    if(WIN32)
        set(NUNUGET_NAME "${NUNUGET_NAME}.exe")
    endif()

    find_program(NUNUGET_PATH
        NAMES ${NUNUGET_NAME}
    )

    if(NUNUGET_PATH)
        set(NUNUGET_PATH ${NUNUGET_PATH} CACHE FILEPATH "The location of 'NuNuGet' executable" FORCE)
        return()
    endif()

    # Check for a custom tools path, and if it doesn't exist, default to '${CMAKE_BINARY_DIR}/__tools'
    if(NOT NUGET_TOOLS_PATH)
        set(NUGET_TOOLS_PATH "${CMAKE_BINARY_DIR}/__tools")
    endif()

    if(NOT EXISTS "${NUGET_TOOLS_PATH}")
        file(MAKE_DIRECTORY "${NUGET_TOOLS_PATH}")
    endif()

    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
        set(PACKAGE_SYSTEM "linux")
        if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "aarch64")
            set(PACKAGE_ARCH "arm64")
            set(PACKAGE_HASH "SHA256=09dd5c1c873703bc6b964a25843388b03efb96ea1e2280a7ee8da75c5f428da9")
        elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86_64")
            set(PACKAGE_ARCH "x64")
            set(PACKAGE_HASH "SHA256=29802bb6aee754a08d4378f9c66443aff11c660188e4be8e012760de3ca97d22")
        endif()
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        set(PACKAGE_SYSTEM "osx")
        if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "arm64")
            set(PACKAGE_ARCH "arm64")
            set(PACKAGE_HASH "SHA256=e43cc0637363f0b285be7feb71b1317ea6410facc5543c2f8d779c58f1402fd4")
        endif()
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(PACKAGE_SYSTEM "win")
        if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "ARM64")
            set(PACKAGE_ARCH "arm64")
            set(PACKAGE_HASH "SHA256=e7d1cfe864342c9809dca8a0d64211167c5a8ae075c03c3bf567a239458b7805")
        elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "AMD64")
            set(PACKAGE_ARCH "x64")
            set(PACKAGE_HASH "SHA256=9053a7cf20239de4a7485fec65934b6460152c05340c57d64d10cd85759d7694")
        endif()
    else()
        message(FATAL_ERROR "ensure_nunuget: Unsupported system name '${CMAKE_HOST_SYSTEM_NAME}'")
    endif()

    if(NOT PACKAGE_ARCH)
        message(FATAL_ERROR "ensure_nunuget: Unsupported system processor '${CMAKE_HOST_SYSTEM_PROCESSOR}'")
    endif()

    set(PACKAGE_NAME "MSchofie.NuNuGet.${PACKAGE_SYSTEM}-${PACKAGE_ARCH}")
    set(PACKAGE_VERSION "0.1.27-beta")

    set(PACKAGE_URL "https://github.com/mschofie/NuNuGet/releases/download/v${PACKAGE_VERSION}/${PACKAGE_NAME}.${PACKAGE_VERSION}.nupkg")
    set(PACKAGE_PATH "${NUGET_TOOLS_PATH}/${PACKAGE_NAME}.${PACKAGE_VERSION}.nupkg")

    file(DOWNLOAD "${PACKAGE_URL}" "${PACKAGE_PATH}"
        EXPECTED_HASH ${PACKAGE_HASH}
    )

    file(ARCHIVE_EXTRACT
        INPUT "${PACKAGE_PATH}"
        DESTINATION "${NUGET_TOOLS_PATH}/${PACKAGE_NAME}.${PACKAGE_VERSION}/"
    )

    set(NUNUGET_PATH "${NUGET_TOOLS_PATH}/${PACKAGE_NAME}.${PACKAGE_VERSION}/tools/any/${PACKAGE_SYSTEM}-${PACKAGE_ARCH}/${NUNUGET_NAME}")
    set(NUNUGET_PATH "${NUNUGET_PATH}" CACHE FILEPATH "The location of 'NuNuGet' executable" FORCE)

    if(NOT WIN32)
        file(CHMOD "${NUNUGET_PATH}" FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    endif()

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
            CONFIG_FILE <config file path>
            LOCK_FILE <lock file path>
            [FRAMEWORK <framework>]
        )

    Note:
        * Package versions can use floating version syntax, according to [the NuGet documentation on Package versioning](https://learn.microsoft.com/en-us/nuget/concepts/package-versioning).

        * `CONFIG_FILE` is the path to the NuGet.config file that should be used when resolving the NuGet packages.
            Only the specified config file will be used.

        * `LOCK_FILE` is the path to the lock file that will be generated/used when resolving the NuGet packages. If
            the specified lock file already exists, then it will be used to resolve the packages, and if there are any
            discrepancies between the specified packages and the packages in the lock file, then an error will be
            reported. If the specified lock file does not exist, then it will be generated with the resolved packages.

            The lock file should be in the source tree and checked into source control to ensure consistent package
            resolution across different machines and build configurations.

        * `FRAMEWORK` is an optional argument that specifies the target framework to use.

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
            CONFIG_FILE
                <config file path>
            LOCK_FILE
                <lock file path>
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

        message(CHECK_START "Installing NuGet packages")
        list(APPEND CMAKE_MESSAGE_INDENT "  ")

        set(OPTIONS)
        set(ONE_VALUE_KEYWORDS CONFIG_FILE LOCK_FILE FRAMEWORK)
        set(MULTI_VALUE_KEYWORDS PACKAGES)

        cmake_parse_arguments(PARSE_ARGV 0 ADD_NUGET "${OPTIONS}" "${ONE_VALUE_KEYWORDS}" "${MULTI_VALUE_KEYWORDS}")

        if(NOT ADD_NUGET_FRAMEWORK)
            set(ADD_NUGET_FRAMEWORK "any")
        endif()

        if(NOT ADD_NUGET_CONFIG_FILE)
            message(FATAL_ERROR "add_nuget_packages: 'CONFIG_FILE' is required.")
        endif()

        if(NOT ADD_NUGET_LOCK_FILE)
            message(FATAL_ERROR "add_nuget_packages: 'LOCK_FILE' is required.")
        endif()

        # Get policy CMP0074:
        #   if OLD, the '${PACKAGE_NAME}_DIR' should point to the NuGet package location
        #   if NEW, the '${PACKAGE_NAME}_ROOT' should point to the NuGet package location
        cmake_policy(GET CMP0074 POLICY_CMP0074)

        # Get policy CMP0144:
        #   if OLD, the '${PACKAGE_NAME}_ROOT' should point to the NuGet package location
        #   if NEW, the '${PACKAGE_NAME_UPPER}_ROOT' should point to the NuGet package location
        cmake_policy(GET CMP0144 POLICY_CMP0144)

        # Enumerate the packages and convert them into a JSON array to pass to NuNuGet, which will resolve the packages
        # and output the resolved package versions and paths to the specified lock file.
        set(PACKAGE_ENTRIES)
        while(ADD_NUGET_PACKAGES)
            list(POP_FRONT ADD_NUGET_PACKAGES PACKAGE_NAME)
            list(POP_FRONT ADD_NUGET_PACKAGES PACKAGE_VERSION)

            if((PACKAGE_NAME STREQUAL "") OR (PACKAGE_VERSION STREQUAL ""))
                message(FATAL_ERROR "add_nuget_packages: 'PACKAGES' must be passed valid NuGet name/version pairs.")
            endif()

            list(APPEND PACKAGE_ENTRIES "{ \"id\": \"${PACKAGE_NAME}\", \"version\": \"${PACKAGE_VERSION}\" }")
        endwhile()

        # Configure the JSON file to pass to NuNuGet with the list of packages to resolve.
        list(JOIN PACKAGE_ENTRIES ",\n    " PACKAGE_ENTRIES)
        configure_file(
            "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/packages.list.json.in"
            "${CMAKE_BINARY_DIR}/${CMAKE_PROJECT_NAME}.packages.list.json"
            @ONLY
        )

        # Make sure that 'nunuget' is available, then invoke it to install the packages to the global packages path.
        ensure_nunuget()
        message(VERBOSE "Invoking NuNuGet with the following arguments: --configFile ${ADD_NUGET_CONFIG_FILE} --listFile ${CMAKE_BINARY_DIR}/${CMAKE_PROJECT_NAME}.packages.list.json --lockFile ${ADD_NUGET_LOCK_FILE}")
        execute_process(
            COMMAND "${NUNUGET_PATH}" install
                --configFile "${ADD_NUGET_CONFIG_FILE}"
                --listFile "${CMAKE_BINARY_DIR}/${CMAKE_PROJECT_NAME}.packages.list.json"
                --lockFile "${ADD_NUGET_LOCK_FILE}"
                --verbose
            RESULT_VARIABLE NUNUGET_RESULT
            OUTPUT_VARIABLE NUNUGET_OUTPUT
            ERROR_VARIABLE NUNUGET_ERROR
        )

        if(NUNUGET_RESULT)
            if(NUNUGET_RESULT EQUAL 100)
                message(FATAL_ERROR "add_nuget_packages: The specified NuGet packages differ from the lock file: ${ADD_NUGET_LOCK_FILE}.\nPlease delete the lock file and re-run configuration to regenerate the lock file with the updated packages.")
            endif()
            message(FATAL_ERROR "add_nuget_packages: NuNuGet failed with exit code ${NUNUGET_RESULT}. Output: ${NUNUGET_OUTPUT}\nError: ${NUNUGET_ERROR}")
        endif()

        # Convert the output from NuNuGet into a list of lines to parse the resolved packages and their paths.
        string(REGEX REPLACE "\r?\n\r?" ";" NUNUGET_OUTPUT "${NUNUGET_OUTPUT}")

        while(NUNUGET_OUTPUT)
            list(POP_FRONT NUNUGET_OUTPUT PACKAGE_LINE)
            if(PACKAGE_LINE MATCHES "GlobalPackagesPath: (.+)")
                set(GLOBAL_PACKAGES_PATH "${CMAKE_MATCH_1}")
                break()
            endif()
        endwhile()

        if(NOT GLOBAL_PACKAGES_PATH)
            message(FATAL_ERROR "add_nuget_packages: Unable to identify the global packages path.")
        endif()
        message(VERBOSE "Global packages path: ${GLOBAL_PACKAGES_PATH}")

        # Parse the packages from NuNuGet output.
        while(NUNUGET_OUTPUT)
            list(POP_FRONT NUNUGET_OUTPUT PACKAGE_LINE)
            if(NOT (PACKAGE_LINE MATCHES "Package: ([^\\]*)/(.*)"))
                continue()
            endif()

            set(PACKAGE_NAME ${CMAKE_MATCH_1})
            set(PACKAGE_VERSION ${CMAKE_MATCH_2})

            string(TOUPPER ${PACKAGE_NAME} PACKAGE_NAME_UPPER)
            string(TOLOWER ${PACKAGE_NAME} PACKAGE_NAME_LOWER)

            message(STATUS "NuGet package: ${PACKAGE_NAME}/${PACKAGE_VERSION}")

            # The location of the package in the global packages folder is: ${GLOBAL_PACKAGES_PATH}/${PACKAGE_NAME_LOWER}/${PACKAGE_VERSION}
            cmake_path(SET NUGET_LOCATION NORMALIZE "${GLOBAL_PACKAGES_PATH}/${PACKAGE_NAME_LOWER}/${PACKAGE_VERSION}")

            # Build 'PACKAGE_NAME_PROPERTY' - the CMake-property friendly form of PACKAGE_NAME.
            #   1. convert to uppercase to follow CMake variable naming conventions
            #   2. replace '.' and '-' with '_' to make it a valid CMake variable name
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

            message(VERBOSE "Setting 'NUGET_VERSION-${PACKAGE_NAME_PROPERTY}' to ${PACKAGE_VERSION}")
            set_property(GLOBAL PROPERTY "NUGET_VERSION-${PACKAGE_NAME_PROPERTY}" ${PACKAGE_VERSION})

            message(VERBOSE "Setting 'NUGET_LOCATION-${PACKAGE_NAME_PROPERTY}' to ${NUGET_LOCATION}")
            set_property(GLOBAL PROPERTY "NUGET_LOCATION-${PACKAGE_NAME_PROPERTY}" ${NUGET_LOCATION})

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

                break()
            endforeach()
        endwhile()

        # Add the lock file as a dependency for the directory, so that if the lock file changes, CMake will re-run
        # configuration. This allows NuGet versions to be re-resolved by deleting the lock file.
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${ADD_NUGET_LOCK_FILE}")

        list(POP_BACK CMAKE_MESSAGE_INDENT)
        message(CHECK_PASS "done")
    endblock()
endfunction()
