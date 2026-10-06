project(org.webosports.app.remote)
cmake_minimum_required(VERSION 3.5)

include(webOS/webOS)
webos_modules_init(1 0 0 QUALIFIER RC3)
webos_component(1 0 0)

set(APP_DIR ${WEBOS_INSTALL_WEBOS_APPLICATIONSDIR}/org.webosports.app.remote)

# The code database: Flipper-IRDB (CC0) turned into the app's JSON by
# tools/build-irdb.py. The checkout is a separate source, passed in as
# IRDB_SOURCE_DIR, so the database can be bumped without touching the app.
if(NOT IRDB_SOURCE_DIR)
    message(FATAL_ERROR "Set IRDB_SOURCE_DIR to a Flipper-IRDB checkout")
endif()

find_package(Python3 REQUIRED COMPONENTS Interpreter)

add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/irdb/index.json
                   COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tools/build-irdb.py
                           ${IRDB_SOURCE_DIR} ${CMAKE_BINARY_DIR}/irdb
                   DEPENDS ${CMAKE_SOURCE_DIR}/tools/build-irdb.py
                   COMMENT "Converting Flipper-IRDB")
add_custom_target(irdb ALL DEPENDS ${CMAKE_BINARY_DIR}/irdb/index.json)

# app payload
install(DIRECTORY qml DESTINATION ${APP_DIR})
install(DIRECTORY ${CMAKE_BINARY_DIR}/irdb DESTINATION ${APP_DIR})
install(FILES appinfo.json icon.png DESTINATION ${APP_DIR})

# luna-service2: register the app id and grant it irblasterd's ir.operation
# group, which is all it needs to send.
configure_file(sysbus/org.webosports.app.remote.manifest.json.in
               ${CMAKE_BINARY_DIR}/org.webosports.app.remote.manifest.json @ONLY)
install(FILES sysbus/org.webosports.app.remote.app.json
        DESTINATION share/luna-service2/roles.d)
install(FILES ${CMAKE_BINARY_DIR}/org.webosports.app.remote.manifest.json
        DESTINATION share/luna-service2/manifests.d)
install(FILES sysbus/org.webosports.app.remote.perm.json
        DESTINATION share/luna-service2/client-permissions.d)
