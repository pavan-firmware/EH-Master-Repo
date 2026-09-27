//! EH Home Desktop — Tauri v2 Core Library

pub mod commands;

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            commands::get_app_info,
            commands::check_native_service_status,
            commands::list_serial_ports,
            commands::identify_esp32_device,
            commands::flash_device_sidecar,
            commands::verify_device_sidecar,
            commands::print_label_native,
        ])
        .run(tauri::generate_context!())
        .expect("error while running EH Home Desktop application");
}
