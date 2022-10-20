find_package(Corrosion REQUIRED)

corrosion_import_crate(MANIFEST_PATH ../rust/Cargo.toml CRATES ten_ten_one)

# Flutter-specific

set(CRATE_NAME "ten_ten_one")

target_link_libraries(${BINARY_NAME} PUBLIC ${CRATE_NAME})

list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${CRATE_NAME}-shared>)
