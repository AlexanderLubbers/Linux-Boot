#include <stdint.h>

// search for the rsdp signature in memory region 0x000E0000 to 0x000FFFFF
// return location of rsdp table if found, else return 0
uintptr_t search_memory() {
    uintptr_t address = 0x000e0000;
    // note it is possible for RSDP to be at this address
    uintptr_t end_address = 0x000fffff;
    char rsdp_signature[8] = {'R', 'S', 'D', ' ', 'P', 'T', 'R', ' '};
    while (address <= end_address) {
        volatile char *ptr = (volatile char *)address;
        int same = 1;
        for (int i = 0; i < 8; i++) {
            char val = *ptr;
            if (val != rsdp_signature[i]) {
                same = 0;
                break;
            }
            ptr = ptr + 1;
        }
        if (same == 1) return address;
        address = address + 16; // rsdp signature is found on 16 byte boundary
    }
    return 0;
}
// search the extended BIOS Data Area for rsdp signature
// return location of rsdp table if found, else return 0
uintptr_t search_EBDA() {
    uintptr_t ebda_location = 0x40e;
    volatile uint16_t ebda_address = *(volatile uint16_t *)ebda_location;
    uintptr_t ebda = ebda_address * 0x10;
    uintptr_t upper_bound = ebda + 0x400;
    char rsdp_signature[8] = {'R', 'S', 'D', ' ', 'P', 'T', 'R', ' '};
    while (ebda <= upper_bound) {
        volatile char *ptr = (volatile char *)ebda;
        int same = 1;
        for (int i = 0; i < 8; i++) {
            char val = *ptr;
            if (val != rsdp_signature[i]) {
                same = 0;
                break;
            }
            ptr = ptr + 1;
        }
        if (same == 1) return ebda;
        ebda = ebda + 16;
    }
    return 0;
}

// finds location of rsdp table in RAM
// then places the value in rax. (calling convention says integer / pointer values returned in rax)
uintptr_t find_rsdp() {
    uintptr_t result = search_memory();
    if (result != 0) return result;
    result = search_EBDA();
    if (result != 0) return result;
    return 0;
}