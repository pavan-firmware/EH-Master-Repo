//! EH Home Desktop — Tauri v2 Core Library

pub mod commands;

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            use tauri::Manager;
            if let Some(window) = app.get_webview_window("main") {
                let icon = tauri::include_image!("icons/128x128.png");
                let _ = window.set_icon(icon);
                let app_handle = app.handle().clone();
                window.on_window_event(move |event| {
                    if matches!(event, tauri::WindowEvent::CloseRequested { .. }) {
                        if let Some(terminal) = app_handle.get_webview_window("provisioning-terminal") {
                            let _ = terminal.destroy();
                        }
                    }
                });
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_app_info,
            commands::check_native_service_status,
            commands::list_serial_ports,
            commands::identify_esp32_device,
            commands::flash_device_sidecar,
            commands::verify_device_sidecar,
            commands::print_label_native,
            commands::list_printers_native,
            commands::print_pdf_document_native,
            commands::check_system_requirements_native,
            commands::check_python_manufacturing_runtime_native,
            commands::enumerate_usb_devices_native,
            commands::check_scanner_subsystem_native,
            commands::check_network_connectivity_native,
            commands::get_setup_diagnostics_native,
            commands::get_repository_workspace_info,
            commands::list_repository_files,
            commands::read_source_file_content,
            commands::get_github_auth_status,
            commands::set_github_token_native,
            commands::clear_github_token_native,
            commands::open_provisioning_terminal_window,
            commands::close_provisioning_terminal_window,
            commands::send_serial_command,
            commands::sync_mobile_catalog_assets,
        ])
        .run(tauri::generate_context!())
        .expect("error while running EH Home Desktop application");
}
