use lib_flutter_rust_bridge_codegen::config_parse;
use lib_flutter_rust_bridge_codegen::frb_codegen;
use lib_flutter_rust_bridge_codegen::get_symbols_if_no_duplicates;
use lib_flutter_rust_bridge_codegen::RawOpts;

const RUST_INPUT: &str = "src/api.rs";
const RUST_OUTPUT: &str = "src/bridge_generated/bridge_generated.rs";
const DART_OUTPUT: &str = "../lib/generated/bridge_generated.dart";
const IOS_C_OUTPUT: &str = "../ios/Runner/bridge_generated.h";
const MACOS_C_OUTPUT: &str = "../macos/Runner/bridge_generated.h";
const DART_DECL_OUTPUT: &str = "../lib/generated/bridge_definitions.dart";

fn main() {
    // Tell Cargo that if the input Rust code changes, to rerun this build script.
    println!("cargo:rerun-if-changed={}", RUST_INPUT);
    // Options for frb_codegen
    let raw_opts = RawOpts {
        rust_input: vec![RUST_INPUT.to_string()],
        rust_output: Some(vec![RUST_OUTPUT.to_string()]),
        dart_output: vec![DART_OUTPUT.to_string()],
        c_output: Some(vec![IOS_C_OUTPUT.to_string(), MACOS_C_OUTPUT.to_string()]),
        dart_decl_output: Some(DART_DECL_OUTPUT.to_string()),
        dart_format_line_length: 100,
        wasm: true,
        // for other options use defaults
        ..Default::default()
    };
    // get opts from raw opts
    let configs = config_parse(raw_opts);

    // generation of rust api for ffi
    let all_symbols = get_symbols_if_no_duplicates(&configs).unwrap();
    for config in configs.iter() {
        frb_codegen(config, &all_symbols).unwrap();
    }
}
