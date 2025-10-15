#[[====================================================================================================================

    Microsoft.WindowsAppSDK.InteractiveExperiences

    CMake configuration file for Microsoft.WindowsAppSDK.InteractiveExperiences package.

    This package provides CMake targets:

        find_package(Microsoft.WindowsAppSDK.InteractiveExperiences CONFIG REQUIRED)

        target_link_libraries(<your-target>
            PRIVATE
                Microsoft.WindowsAppSDK.InteractiveExperiences
        )

    License:
        See the LICENSE file in the package root for more information.
====================================================================================================================]]#
include_guard()

find_package(Microsoft.Windows.CppWinRT CONFIG REQUIRED)

if(NOT (TARGET Microsoft.Windows.CppWinRT))
    message(FATAL_ERROR "Microsoft.Windows.CppWinRT not found. Ensure that the Microsoft.Windows.CppWinRT dependency is correctly specified.")
endif()

block(SCOPE_FOR VARIABLES)
    # Set the 'PLATFORM_IDENTIFIER' - mapping CMake constructs to the identifiers that the NuGet package layout uses.
    if(CMAKE_GENERATOR MATCHES "^Visual Studio")
        set(PLATFORM_IDENTIFIER ${CMAKE_GENERATOR_PLATFORM})
    else()
        set(PLATFORM_PROCESSOR ${CMAKE_SYSTEM_PROCESSOR})
        if(PLATFORM_PROCESSOR STREQUAL "")
            set(PLATFORM_PROCESSOR ${CMAKE_HOST_PROCESSOR})
        endif()
        if(PLATFORM_PROCESSOR STREQUAL "AMD64")
            set(PLATFORM_IDENTIFIER "x64")
        elseif(PLATFORM_PROCESSOR STREQUAL "ARM64")
            set(PLATFORM_IDENTIFIER "arm64")
        endif()
    endif()

    if(PLATFORM_IDENTIFIER STREQUAL "")
        message(FATAL_ERROR "Unable to determine the platform identifier.")
    endif()

    # For 'overlay' configuration, rely on the 'NUGET_LOCATION-<package name>' global property set by the NuGetCMakePackage.
    # For 'laid out' configuration, this should rely on the location of the current file.
    get_property(PACKAGE_LOCATION GLOBAL PROPERTY NUGET_LOCATION-MICROSOFT_WINDOWSAPPSDK_INTERACTIVEEXPERIENCES)
    get_property(PACKAGE_VERSION  GLOBAL PROPERTY NUGET_VERSION-MICROSOFT_WINDOWSAPPSDK_INTERACTIVEEXPERIENCES)

    #[[====================================================================================================================
        Target: Microsoft.WindowsAppSDK.InteractiveExperiences
    ====================================================================================================================]]#
    add_cppwinrt_projection(Microsoft.WindowsAppSDK.InteractiveExperiences
        INPUTS
            ${PACKAGE_LOCATION}/metadata/10.0.18362.0/Microsoft.Foundation.winmd
            ${PACKAGE_LOCATION}/metadata/10.0.18362.0/Microsoft.Graphics.winmd
            ${PACKAGE_LOCATION}/metadata/10.0.18362.0/Microsoft.UI.winmd
        OPTIMIZE
        DEPS
            Microsoft.Windows.CppWinRT
    )

    target_include_directories(Microsoft.WindowsAppSDK.InteractiveExperiences
        INTERFACE
            ${PACKAGE_LOCATION}/include
    )

    #[[====================================================================================================================
        Target: Microsoft.WindowsAppSDK.InteractiveExperiences_SelfContained
    ====================================================================================================================]]#
    add_library(Microsoft.WindowsAppSDK.InteractiveExperiences_SelfContainedRuntime SHARED IMPORTED GLOBAL)

    set(FRAMEWORK_PATH "${PACKAGE_LOCATION}/runtimes-framework/win-${PLATFORM_IDENTIFIER}/native")
    set(FRAMEWORK_DLLS
        "${FRAMEWORK_PATH}/CoreMessagingXP.dll"
        "${FRAMEWORK_PATH}/dcompi.dll"
        "${FRAMEWORK_PATH}/dwmcorei.dll"
        "${FRAMEWORK_PATH}/DwmSceneI.dll"
        "${FRAMEWORK_PATH}/marshal.dll"
        "${FRAMEWORK_PATH}/Microsoft.DirectManipulation.dll"
        "${FRAMEWORK_PATH}/Microsoft.Graphics.Display.dll"
        "${FRAMEWORK_PATH}/Microsoft.InputStateManager.dll"
        "${FRAMEWORK_PATH}/Microsoft.Internal.FrameworkUdk.dll"
        "${FRAMEWORK_PATH}/Microsoft.UI.Composition.OSSupport.dll"
        "${FRAMEWORK_PATH}/Microsoft.UI.Designer.dll"
        "${FRAMEWORK_PATH}/Microsoft.UI.dll"
        "${FRAMEWORK_PATH}/Microsoft.UI.Input.dll"
        "${FRAMEWORK_PATH}/Microsoft.UI.pri"
        "${FRAMEWORK_PATH}/Microsoft.UI.Windowing.Core.dll"
        "${FRAMEWORK_PATH}/Microsoft.UI.Windowing.dll"
        "${FRAMEWORK_PATH}/wuceffectsi.dll"
    )

    set_target_properties(Microsoft.WindowsAppSDK.InteractiveExperiences_SelfContainedRuntime
        PROPERTIES
            IMPORTED_IMPLIB "${PACKAGE_LOCATION}/lib/native/win10-${PLATFORM_IDENTIFIER}/Microsoft.UI.Dispatching.lib"
            IMPORTED_LOCATION "${FRAMEWORK_DLLS}"
    )

    add_library(Microsoft.WindowsAppSDK.InteractiveExperiences_SelfContained INTERFACE)

    target_sources(Microsoft.WindowsAppSDK.InteractiveExperiences_SelfContained
        INTERFACE
            ${CMAKE_CURRENT_LIST_DIR}/Microsoft.WindowsAppSDK.InteractiveExperiences.manifest
    )

    target_link_options(Microsoft.WindowsAppSDK.InteractiveExperiences_SelfContained
        INTERFACE
            /MANIFEST
    )

    target_link_libraries(Microsoft.WindowsAppSDK.InteractiveExperiences_SelfContained
        INTERFACE
            Microsoft.WindowsAppSDK.InteractiveExperiences
            Microsoft.WindowsAppSDK.InteractiveExperiences_SelfContainedRuntime
    )

endblock()
