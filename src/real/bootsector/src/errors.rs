use super::console::real_mode_println;
use shared::instructions;

#[no_mangle]
extern "C" fn dap_load_failed() -> ! {
    real_mode_println(b"[!] DAP Load Failed");
    loop {
        instructions::hlt()
    }
}

#[no_mangle]
extern "C" fn no_int13h_extensions() -> ! {
    real_mode_println(b"[!] No int13h Extensions");
    loop {
        instructions::hlt()
    }
}