# My Notes on GDB
## Useful Commands To Know
* continue (continue execution)
* ctrl+c (pause virtual CPU)
* info registers
* x/16bx 0x5000 (16 bytes). other common formats include x/8hx (half words), x/8wx (words)
* si (single step. executes a single instruction)
* break *0x7d20 (stop execution when CPU reaches this address)
* info registers eflags (look at eflags)
* p/x $eax (inspect specific register)