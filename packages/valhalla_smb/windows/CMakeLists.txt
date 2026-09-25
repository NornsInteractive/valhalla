cmake_minimum_required(VERSION 3.14)
project(valhalla_smb_plugin LANGUAGES C)
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")
set(valhalla_smb_bundled_libraries $<TARGET_FILE:valhalla_smb> PARENT_SCOPE)
