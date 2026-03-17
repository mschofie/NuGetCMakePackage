#[[====================================================================================================================

    Convention-Based NuGet Package Configuration
    ---------------------------------------------

    A single generalized config that auto-discovers package contents and creates CMake targets
    for any NuGet package following the WinAppSDK layout convention.

    NuGet Package Structure (WinAppSDK convention):
    ================================================

        metadata/                                   .winmd files for C++/WinRT projection generation
                                                    (may be flat or in versioned subdirs like 10.0.18362.0/)

        lib/native/{arch}/                          Import libraries (.lib) to link against at build time
                                                    (arch = x64, x86, arm64, arm64ec)

        include/                                    C/C++ header files (e.g., MddBootstrap.h, MRM.h)

        runtimes-framework/                         Self-contained deployment assets (arch-specific):
            win-{arch}/native/                        Runtime DLLs that ship alongside the exe
            package.appxfragment                      Activatable class registrations (DLL → WinRT class mappings)

        runtimes/                                   Runtime tools (not self-contained DLLs):
            win-{arch}/native/                        e.g., Microsoft.WindowsAppRuntime.Bootstrap.dll

        build/native/                               MSBuild .props/.targets for C++ projects (not used by CMake)
        buildTransitive/                            MSBuild transitive imports for C# projects (not applicable)

    Created CMake targets:
        * <PackageName>                - C++/WinRT projection + headers + import libs (library target)
        * <PackageName>_SelfContained  - Self-contained deployment: links projection + arch-specific
                                         runtime DLLs from runtimes-framework/ + auto-generated manifest
                                         from package.appxfragment for WinRT class activation
        * <PackageName>_Framework      - Framework-dependent deployment: links projection + import libs,
                                         optionally wires bootstrap auto-initialization

    This file is invoked by find_package() when the convention fallback is active.
    CMAKE_FIND_PACKAGE_NAME identifies which package is being configured.

====================================================================================================================]]#
# No include_guard — this file runs once per package via CMAKE_FIND_PACKAGE_NAME

if(CMAKE_VERSION VERSION_LESS 3.31)
    message(FATAL_ERROR "Convention-based config requires at least CMake 3.31.")
endif()

# Determine which package we're configuring
# Use a counter to create unique variable names to handle re-entrant includes
get_property(_CONV_DEPTH GLOBAL PROPERTY "_CONVENTION_DEPTH")
if("${_CONV_DEPTH}" STREQUAL "")
    set(_CONV_DEPTH 0)
endif()
math(EXPR _CONV_DEPTH "${_CONV_DEPTH} + 1")
set_property(GLOBAL PROPERTY "_CONVENTION_DEPTH" ${_CONV_DEPTH})

set(_CONV_PKG_${_CONV_DEPTH} ${CMAKE_FIND_PACKAGE_NAME})

if("${_CONV_PKG_${_CONV_DEPTH}}" STREQUAL "")
    message(FATAL_ERROR "Convention config: CMAKE_FIND_PACKAGE_NAME is not set.")
endif()

# Skip if already processed (re-entrant guard) — must be BEFORE any find_package calls
string(TOUPPER "${_CONV_PKG_${_CONV_DEPTH}}" _TMP_UPPER)
string(REPLACE "." "_" _TMP_PROP "${_TMP_UPPER}")
get_property(_CONV_ALREADY_DONE GLOBAL PROPERTY "_CONVENTION_DONE_${_TMP_PROP}")
if(_CONV_ALREADY_DONE OR TARGET ${_CONV_PKG_${_CONV_DEPTH}})
    set(${_CONV_PKG_${_CONV_DEPTH}}_FOUND TRUE)
    math(EXPR _CONV_DEPTH "${_CONV_DEPTH} - 1")
    set_property(GLOBAL PROPERTY "_CONVENTION_DEPTH" ${_CONV_DEPTH})
    return()
endif()
set_property(GLOBAL PROPERTY "_CONVENTION_DONE_${_TMP_PROP}" TRUE)

# Now set the working variable name for the rest of the file
set(_CONV_PACKAGE_NAME ${_CONV_PKG_${_CONV_DEPTH}})

# Use block() to isolate variables — nested find_package calls re-enter this file
block(SCOPE_FOR VARIABLES POLICIES)

# Resolve package location
string(TOUPPER "${_CONV_PACKAGE_NAME}" _CONV_UPPER)
string(REPLACE "." "_" _CONV_PROP "${_CONV_UPPER}")
string(REPLACE "-" "_" _CONV_PROP "${_CONV_PROP}")
get_property(_CONV_PKG_LOC GLOBAL PROPERTY "NUGET_LOCATION-${_CONV_PROP}")
get_property(_CONV_PKG_VER GLOBAL PROPERTY "NUGET_VERSION-${_CONV_PROP}")

if("${_CONV_PKG_LOC}" STREQUAL "")
    message(FATAL_ERROR "Convention config: Package '${_CONV_PACKAGE_NAME}' location not found.")
endif()

# Ensure CppWinRT is available for projection generation
find_package(Microsoft.Windows.CppWinRT CONFIG QUIET)

#----------------------------------------------------------------------------------------------------------------------
# Auto-resolve dependencies by parsing the package's .nuspec file
#----------------------------------------------------------------------------------------------------------------------
file(GLOB _CONV_NUSPEC "${_CONV_PKG_LOC}/*.nuspec")
if(_CONV_NUSPEC)
    list(GET _CONV_NUSPEC 0 _CONV_NUSPEC_FILE)
    file(READ "${_CONV_NUSPEC_FILE}" _CONV_NUSPEC_CONTENT)
    # Extract dependency IDs: <dependency id="Package.Name" .../>
    string(REGEX MATCHALL "dependency id=\"([^\"]+)\"" _CONV_DEP_MATCHES "${_CONV_NUSPEC_CONTENT}")
    foreach(_MATCH IN LISTS _CONV_DEP_MATCHES)
        string(REGEX MATCH "dependency id=\"([^\"]+)\"" _ "${_MATCH}")
        set(_DEP_NAME "${CMAKE_MATCH_1}")
        # Only auto-find WinAppSDK component packages (not SDK.BuildTools etc.)
        if(_DEP_NAME MATCHES "^Microsoft\\.WindowsAppSDK\\." OR _DEP_NAME MATCHES "^Microsoft\\.Windows\\.CppWinRT$")
            find_package(${_DEP_NAME} CONFIG QUIET)
        endif()
    endforeach()
endif()

#----------------------------------------------------------------------------------------------------------------------
# Platform detection
#----------------------------------------------------------------------------------------------------------------------
if(CMAKE_GENERATOR MATCHES "^Visual Studio")
    set(_CONV_PLATFORM ${CMAKE_GENERATOR_PLATFORM})
else()
    set(_CONV_PROC ${CMAKE_SYSTEM_PROCESSOR})
    if("${_CONV_PROC}" STREQUAL "")
        set(_CONV_PROC ${CMAKE_HOST_SYSTEM_PROCESSOR})
    endif()
    if(_CONV_PROC STREQUAL "AMD64")
        set(_CONV_PLATFORM "x64")
    elseif(_CONV_PROC STREQUAL "ARM64")
        set(_CONV_PLATFORM "arm64")
    elseif(_CONV_PROC STREQUAL "X86")
        set(_CONV_PLATFORM "x86")
    endif()
endif()

if("${_CONV_PLATFORM}" STREQUAL "")
    message(FATAL_ERROR "Convention config: Unable to determine platform.")
endif()

message(STATUS "Convention config: ${_CONV_PACKAGE_NAME}/${_CONV_PKG_VER} [${_CONV_PLATFORM}]")

#----------------------------------------------------------------------------------------------------------------------
# 1. Discover WinMD files under metadata/ and create C++/WinRT projection
#    metadata/ contains .winmd files that define WinRT API surface.
#    cppwinrt.exe processes these to generate C++ header files for consumption.
#----------------------------------------------------------------------------------------------------------------------
file(GLOB_RECURSE _CONV_WINMDS "${_CONV_PKG_LOC}/metadata/*.winmd")

if(_CONV_WINMDS AND TARGET Microsoft.Windows.CppWinRT)
    # Collect dependency projections. Check for other WinAppSDK component targets
    # that have already been created (they provide WinMD references needed for projection).
    set(_CONV_PROJECTION_DEPS Microsoft.Windows.CppWinRT)
    foreach(_DEP_TARGET
        Microsoft.WindowsAppSDK.InteractiveExperiences
        Microsoft.WindowsAppSDK.Foundation
        Microsoft.WindowsAppSDK.WinUI
        Microsoft.WindowsAppSDK.ML
        Microsoft.WindowsAppSDK.AI
        Microsoft.WindowsAppSDK.DWrite
        Microsoft.WindowsAppSDK.Widgets
        Microsoft.WindowsAppSDK.Search
    )
        if(TARGET ${_DEP_TARGET} AND NOT ("${_DEP_TARGET}" STREQUAL "${_CONV_PACKAGE_NAME}"))
            list(APPEND _CONV_PROJECTION_DEPS ${_DEP_TARGET})
        endif()
    endforeach()

    add_cppwinrt_projection(${_CONV_PACKAGE_NAME}
        INPUTS ${_CONV_WINMDS}
        OPTIMIZE
        DEPS ${_CONV_PROJECTION_DEPS}
    )
else()
    add_library(${_CONV_PACKAGE_NAME} INTERFACE)
endif()

# Add include/ directories (C/C++ headers like MddBootstrap.h, MRM.h, OnnxRuntime headers)
if(IS_DIRECTORY "${_CONV_PKG_LOC}/include")
    target_include_directories(${_CONV_PACKAGE_NAME} INTERFACE "${_CONV_PKG_LOC}/include")
endif()

#----------------------------------------------------------------------------------------------------------------------
# 2. Discover arch-specific DLLs under runtimes-framework/ for self-contained deployment
#    runtimes-framework/win-{arch}/native/ contains the DLLs that must ship alongside
#    the exe for self-contained apps. These are the same DLLs that the WinAppSDK Framework
#    MSIX package would provide in framework-dependent mode.
#    lib/native/{arch}/ contains import libraries (.lib) to link against at build time.
#----------------------------------------------------------------------------------------------------------------------
set(_CONV_FW_PATH "${_CONV_PKG_LOC}/runtimes-framework/win-${_CONV_PLATFORM}/native")
set(_CONV_HAS_FW_DLLS FALSE)

if(IS_DIRECTORY "${_CONV_FW_PATH}")
    file(GLOB _CONV_FW_DLLS "${_CONV_FW_PATH}/*.dll")
    file(GLOB _CONV_FW_PRI  "${_CONV_FW_PATH}/*.pri")
    list(APPEND _CONV_FW_DLLS ${_CONV_FW_PRI})

    if(_CONV_FW_DLLS)
        set(_CONV_HAS_FW_DLLS TRUE)

        add_library(${_CONV_PACKAGE_NAME}_SelfContainedRuntime SHARED IMPORTED GLOBAL)

        # Find import libs from lib/native/{arch}/ or lib/native/win10-{arch}/ (older layout)
        # Exclude bootstrap lib (it's for framework-dependent, not self-contained)
        file(GLOB _CONV_IMPORT_LIBS "${_CONV_PKG_LOC}/lib/native/${_CONV_PLATFORM}/*.lib")
        if(NOT _CONV_IMPORT_LIBS)
            file(GLOB _CONV_IMPORT_LIBS "${_CONV_PKG_LOC}/lib/native/win10-${_CONV_PLATFORM}/*.lib")
        endif()
        set(_CONV_SC_LIBS "")
        foreach(_lib IN LISTS _CONV_IMPORT_LIBS)
            get_filename_component(_lib_name "${_lib}" NAME)
            if(NOT _lib_name STREQUAL "Microsoft.WindowsAppRuntime.Bootstrap.lib")
                list(APPEND _CONV_SC_LIBS "${_lib}")
            endif()
        endforeach()

        if(_CONV_SC_LIBS)
            list(GET _CONV_SC_LIBS 0 _CONV_PRIMARY_LIB)
            set_target_properties(${_CONV_PACKAGE_NAME}_SelfContainedRuntime PROPERTIES
                IMPORTED_IMPLIB "${_CONV_PRIMARY_LIB}"
                IMPORTED_LOCATION "${_CONV_FW_DLLS}"
            )
            # Link additional import libs beyond the first
            list(LENGTH _CONV_SC_LIBS _CONV_SC_LIBS_COUNT)
            if(_CONV_SC_LIBS_COUNT GREATER 1)
                list(SUBLIST _CONV_SC_LIBS 1 -1 _CONV_EXTRA_LIBS)
                target_link_libraries(${_CONV_PACKAGE_NAME}_SelfContainedRuntime INTERFACE ${_CONV_EXTRA_LIBS})
            endif()
        else()
            set_target_properties(${_CONV_PACKAGE_NAME}_SelfContainedRuntime PROPERTIES
                IMPORTED_LOCATION "${_CONV_FW_DLLS}"
            )
        endif()
    endif()
endif()

#----------------------------------------------------------------------------------------------------------------------
# 3. Parse AppX fragment for self-contained WinRT class activation manifest
#    runtimes-framework/package.appxfragment contains activatable class registrations
#    mapping WinRT class IDs to their implementing DLLs. For self-contained deployment,
#    these must be embedded as an SxS manifest in the exe so UndockedRegFreeWinRT can
#    activate WinRT classes without MSIX package identity.
#    Fallback: build/native/LiftedWinRTClassRegistrations.xml (older convention)
#----------------------------------------------------------------------------------------------------------------------
set(_CONV_MANIFEST_FILE "")
set(_CONV_APPX_FRAGMENTS)
file(GLOB _CONV_APPX_FRAGMENTS
    "${_CONV_PKG_LOC}/runtimes-framework/package.appxfragment"
    "${_CONV_PKG_LOC}/build/native/LiftedWinRTClassRegistrations.xml"
    "${_CONV_PKG_LOC}/buildTransitive/native/LiftedWinRTClassRegistrations.xml"
)

if(_CONV_APPX_FRAGMENTS)
    list(GET _CONV_APPX_FRAGMENTS 0 _CONV_FRAGMENT_FILE)

    file(READ "${_CONV_FRAGMENT_FILE}" _CONV_FRAGMENT_CONTENT)

    # Generate a manifest file at configure time
    set(_CONV_MANIFEST_FILE "${CMAKE_BINARY_DIR}/__manifests/${_CONV_PACKAGE_NAME}.manifest")
    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/__manifests")

    # Parse line-by-line: track current DLL from <Path> tags, collect <ActivatableClass> entries
    string(REGEX REPLACE "\r?\n" ";" _CONV_LINES "${_CONV_FRAGMENT_CONTENT}")

    set(_CONV_MANIFEST_ENTRIES "")
    set(_CONV_CURRENT_DLL "")
    set(_CONV_CURRENT_CLASSES "")

    foreach(_LINE IN LISTS _CONV_LINES)
        # Match <Path>DLL.dll</Path>
        if(_LINE MATCHES "<Path>([^<]+)</Path>")
            # Flush previous DLL's classes
            if(_CONV_CURRENT_DLL AND _CONV_CURRENT_CLASSES)
                string(APPEND _CONV_MANIFEST_ENTRIES "    <file name=\"${_CONV_CURRENT_DLL}\">\n${_CONV_CURRENT_CLASSES}    </file>\n")
            endif()
            set(_CONV_CURRENT_DLL "${CMAKE_MATCH_1}")
            set(_CONV_CURRENT_CLASSES "")
        endif()

        # Match <ActivatableClass ActivatableClassId="X" .../>
        if(_LINE MATCHES "ActivatableClassId=\"([^\"]+)\"")
            string(APPEND _CONV_CURRENT_CLASSES "        <activatableClass name=\"${CMAKE_MATCH_1}\" threadingModel=\"both\" xmlns=\"urn:schemas-microsoft-com:winrt.v1\" />\n")
        endif()
    endforeach()

    # Flush last DLL
    if(_CONV_CURRENT_DLL AND _CONV_CURRENT_CLASSES)
        string(APPEND _CONV_MANIFEST_ENTRIES "    <file name=\"${_CONV_CURRENT_DLL}\">\n${_CONV_CURRENT_CLASSES}    </file>\n")
    endif()

    if(_CONV_MANIFEST_ENTRIES)
        file(WRITE "${_CONV_MANIFEST_FILE}"
            "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
            "<assembly xmlns=\"urn:schemas-microsoft-com:asm.v1\" manifestVersion=\"1.0\">\n"
            "${_CONV_MANIFEST_ENTRIES}"
            "</assembly>\n"
        )
    else()
        set(_CONV_MANIFEST_FILE "")
    endif()
endif()

#----------------------------------------------------------------------------------------------------------------------
# 4. Create _SelfContained target
#    Links the C++/WinRT projection + arch-specific runtime DLLs from runtimes-framework/
#    + auto-generated manifest from package.appxfragment for WinRT class activation
#----------------------------------------------------------------------------------------------------------------------
add_library(${_CONV_PACKAGE_NAME}_SelfContained INTERFACE)
target_link_libraries(${_CONV_PACKAGE_NAME}_SelfContained INTERFACE ${_CONV_PACKAGE_NAME})

if(TARGET ${_CONV_PACKAGE_NAME}_SelfContainedRuntime)
    target_link_libraries(${_CONV_PACKAGE_NAME}_SelfContained INTERFACE
        ${_CONV_PACKAGE_NAME}_SelfContainedRuntime
    )
endif()

# Add auto-generated manifest from AppX fragment parsing
if(_CONV_MANIFEST_FILE AND EXISTS "${_CONV_MANIFEST_FILE}")
    target_sources(${_CONV_PACKAGE_NAME}_SelfContained INTERFACE "${_CONV_MANIFEST_FILE}")
    target_link_options(${_CONV_PACKAGE_NAME}_SelfContained INTERFACE /MANIFEST)
endif()

#----------------------------------------------------------------------------------------------------------------------
# 5. Create _Framework target
#    Links the C++/WinRT projection + import libs from lib/native/{arch}/
#    Framework-dependent apps rely on the WinAppSDK Framework MSIX package being installed
#    on the target machine (the same DLLs that _SelfContained bundles alongside the exe).
#----------------------------------------------------------------------------------------------------------------------
add_library(${_CONV_PACKAGE_NAME}_Framework INTERFACE)
target_link_libraries(${_CONV_PACKAGE_NAME}_Framework INTERFACE ${_CONV_PACKAGE_NAME})

# Link import libs from lib/native/{arch}/ or lib/native/win10-{arch}/ for framework mode
# Exclude bootstrap lib (it has its own dedicated target wired via target properties)
file(GLOB _CONV_IMPORT_LIBS "${_CONV_PKG_LOC}/lib/native/${_CONV_PLATFORM}/*.lib")
if(NOT _CONV_IMPORT_LIBS)
    file(GLOB _CONV_IMPORT_LIBS "${_CONV_PKG_LOC}/lib/native/win10-${_CONV_PLATFORM}/*.lib")
endif()
foreach(_lib IN LISTS _CONV_IMPORT_LIBS)
    get_filename_component(_lib_name "${_lib}" NAME)
    if(NOT _lib_name STREQUAL "Microsoft.WindowsAppRuntime.Bootstrap.lib")
        target_link_libraries(${_CONV_PACKAGE_NAME}_Framework INTERFACE "${_lib}")
    endif()
endforeach()

#----------------------------------------------------------------------------------------------------------------------
# 6. Bootstrap support (detected generically from package contents)
#    If runtimes/win-{arch}/native/ contains Microsoft.WindowsAppRuntime.Bootstrap.dll
#    and lib/native/{arch}/ contains the matching .lib, this package provides the
#    bootstrapper for framework-dependent unpackaged apps. The bootstrap DLL enables
#    dynamic dependency loading of the WinAppSDK Framework package at runtime.
#    include/ provides auto-initializer source files that handle initialization
#    automatically via static global constructors.
#----------------------------------------------------------------------------------------------------------------------
set(_CONV_BOOTSTRAP_LIB "${_CONV_PKG_LOC}/lib/native/${_CONV_PLATFORM}/Microsoft.WindowsAppRuntime.Bootstrap.lib")
set(_CONV_BOOTSTRAP_DLL "${_CONV_PKG_LOC}/runtimes/win-${_CONV_PLATFORM}/native/Microsoft.WindowsAppRuntime.Bootstrap.dll")
set(_CONV_AUTOINIT_SRC  "${_CONV_PKG_LOC}/include/WindowsAppRuntimeAutoInitializer.cpp")
set(_CONV_BOOTSTRAP_SRC "${_CONV_PKG_LOC}/include/MddBootstrapAutoInitializer.cpp")
set(_CONV_DEPLOYMGR_SRC "${_CONV_PKG_LOC}/include/DeploymentManagerAutoInitializer.cpp")

if(EXISTS "${_CONV_BOOTSTRAP_LIB}" AND EXISTS "${_CONV_BOOTSTRAP_DLL}")
    find_package(Microsoft.WindowsAppSDK.Runtime CONFIG QUIET)
    if(Microsoft.WindowsAppSDK.Runtime_FOUND)
        # Bootstrap shared library
        add_library(${_CONV_PACKAGE_NAME}_Bootstrap SHARED IMPORTED GLOBAL)
        set_target_properties(${_CONV_PACKAGE_NAME}_Bootstrap PROPERTIES
            IMPORTED_IMPLIB "${_CONV_BOOTSTRAP_LIB}"
            IMPORTED_LOCATION "${_CONV_BOOTSTRAP_DLL}"
        )
        if(EXISTS "${_CONV_AUTOINIT_SRC}")
            target_sources(${_CONV_PACKAGE_NAME}_Bootstrap INTERFACE "${_CONV_AUTOINIT_SRC}")
        endif()
        target_link_libraries(${_CONV_PACKAGE_NAME}_Bootstrap INTERFACE Microsoft.WindowsAppSDK.Runtime)

        # DynamicDependencyBootstrap (unpackaged framework-dependent auto-init)
        if(EXISTS "${_CONV_BOOTSTRAP_SRC}")
            add_library(${_CONV_PACKAGE_NAME}_DynamicDependencyBootstrap INTERFACE)
            target_sources(${_CONV_PACKAGE_NAME}_DynamicDependencyBootstrap INTERFACE "${_CONV_BOOTSTRAP_SRC}")
            target_compile_definitions(${_CONV_PACKAGE_NAME}_DynamicDependencyBootstrap INTERFACE
                MICROSOFT_WINDOWSAPPSDK_AUTOINITIALIZE_BOOTSTRAP
            )
            target_link_libraries(${_CONV_PACKAGE_NAME}_DynamicDependencyBootstrap INTERFACE
                ${_CONV_PACKAGE_NAME}_Bootstrap
            )
        endif()

        # DeploymentManagerBootstrap (packaged framework-dependent auto-init)
        if(EXISTS "${_CONV_DEPLOYMGR_SRC}")
            add_library(${_CONV_PACKAGE_NAME}_DeploymentManagerBootstrap INTERFACE)
            target_sources(${_CONV_PACKAGE_NAME}_DeploymentManagerBootstrap INTERFACE "${_CONV_DEPLOYMGR_SRC}")
            target_compile_definitions(${_CONV_PACKAGE_NAME}_DeploymentManagerBootstrap INTERFACE
                MICROSOFT_WINDOWSAPPSDK_AUTOINITIALIZE_DEPLOYMENTMANAGER
            )
            target_link_libraries(${_CONV_PACKAGE_NAME}_DeploymentManagerBootstrap INTERFACE
                ${_CONV_PACKAGE_NAME}_Bootstrap
            )
        endif()

        # Wire bootstrap into _Framework via conditional target properties
        target_link_libraries(${_CONV_PACKAGE_NAME}_Framework INTERFACE
            $<$<BOOL:$<TARGET_PROPERTY:WindowsAppSdkBootstrapInitialize>>:${_CONV_PACKAGE_NAME}_DynamicDependencyBootstrap>
            $<$<BOOL:$<TARGET_PROPERTY:WindowsAppSdkDeploymentManagerInitialize>>:${_CONV_PACKAGE_NAME}_DeploymentManagerBootstrap>
        )
    endif()
endif()

set(${_CONV_PACKAGE_NAME}_FOUND TRUE PARENT_SCOPE)

endblock() # End of block(SCOPE_FOR VARIABLES POLICIES)

# Restore depth counter and package name from stack
get_property(_CONV_DEPTH GLOBAL PROPERTY "_CONVENTION_DEPTH")
math(EXPR _CONV_DEPTH "${_CONV_DEPTH} - 1")
set_property(GLOBAL PROPERTY "_CONVENTION_DEPTH" ${_CONV_DEPTH})
if(_CONV_DEPTH GREATER 0)
    set(_CONV_PACKAGE_NAME ${_CONV_PKG_${_CONV_DEPTH}})
endif()
