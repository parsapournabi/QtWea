
cmake_minimum_required(VERSION 3.16)
project(QtWea VERSION 1.0.0 LANGUAGES CXX)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

add_subdirectory(WeaCore)
add_subdirectory(WeaQuick)

add_library(QtWea::WeaCore ALIAS WeaCore)
add_library(QtWea::WeaQuick ALIAS WeaQuick)

set(QTWEA_COMPONENT_TARGETS
    WeaCore
    WeaQuick
)

install(
    TARGETS ${QTWEA_COMPONENT_TARGETS}
    EXPORT QtWeaTargets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/QtWeaConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/QtWeaConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/QtWeaConfig.cmake"
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/QtWea
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/QtWeaConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/QtWeaConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/QtWea
)

install(EXPORT QtWeaTargets
    NAMESPACE QtWea::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/QtWea
)
