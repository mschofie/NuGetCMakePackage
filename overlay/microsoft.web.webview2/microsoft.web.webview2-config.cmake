#[[====================================================================================================================
    Microsoft.Web.WebView2 — Minimal overlay providing WinMD reference for cppwinrt projections.
====================================================================================================================]]#
include_guard()

if(CMAKE_VERSION VERSION_LESS 3.31)
    message(FATAL_ERROR "Microsoft.Web.WebView2 requires at least CMake 3.31.")
endif()

block(SCOPE_FOR VARIABLES)
    get_property(PACKAGE_LOCATION GLOBAL PROPERTY NUGET_LOCATION-MICROSOFT_WEB_WEBVIEW2)

    add_library(Microsoft.Web.WebView2 INTERFACE)

    # Expose the WinMD as a cppwinrt reference so dependent projections can resolve WebView2 types
    set_target_properties(Microsoft.Web.WebView2 PROPERTIES
        INTERFACE_CPPWINRT_REFS "${PACKAGE_LOCATION}/lib/Microsoft.Web.WebView2.Core.winmd"
    )
endblock()
