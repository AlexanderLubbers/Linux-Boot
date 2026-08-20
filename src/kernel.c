
#include <stdarg.h>
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#define VGA_WIDTH  80
#define VGA_HEIGHT 25
#define VGA_MEMORY ((volatile uint16_t *)0xB8000)

static size_t cursor_row = 0;
static size_t cursor_col = 0;

static uint8_t vga_color = 0x07; // light gray on black


void putc(char c)
{
    if (c == '\n') {
        cursor_col = 0;
        cursor_row++;

        if (cursor_row >= VGA_HEIGHT)
            cursor_row = 0;

        return;
    }

    VGA_MEMORY[cursor_row * VGA_WIDTH + cursor_col] =
        ((uint16_t)vga_color << 8) | (uint8_t)c;

    cursor_col++;

    if (cursor_col >= VGA_WIDTH) {
        cursor_col = 0;
        cursor_row++;

        if (cursor_row >= VGA_HEIGHT)
            cursor_row = 0;
    }
}


void puts(const char *str)
{
    while (*str)
        putc(*str++);
}


void put_unsigned(uint64_t value, unsigned base)
{
    char buffer[32];
    size_t i = 0;

    if (value == 0) {
        putc('0');
        return;
    }

    while (value != 0) {
        uint64_t digit = value % base;

        if (digit < 10)
            buffer[i++] = '0' + digit;
        else
            buffer[i++] = 'a' + (digit - 10);

        value /= base;
    }

    while (i > 0)
        putc(buffer[--i]);
}


void put_signed(int64_t value)
{
    if (value < 0) {
        putc('-');

        /*
         * Avoid overflowing when value == INT64_MIN.
         */
        put_unsigned((uint64_t)(-(value + 1)) + 1, 10);
    }
    else {
        put_unsigned((uint64_t)value, 10);
    }
}


void printf(const char *format, ...)
{
    va_list args;

    va_start(args, format);

    while (*format) {

        if (*format != '%') {
            putc(*format++);
            continue;
        }

        format++;

        switch (*format) {

            case '%':
                putc('%');
                break;

            case 'c':
                putc((char)va_arg(args, int));
                break;

            case 's':
                puts(va_arg(args, const char *));
                break;

            case 'd':
            case 'i':
                put_signed(va_arg(args, int));
                break;

            case 'u':
                put_unsigned(va_arg(args, unsigned int), 10);
                break;

            case 'x':
                put_unsigned(va_arg(args, unsigned int), 16);
                break;

            case 'p':
                putc('0');
                putc('x');
                put_unsigned(
                    (uint64_t)va_arg(args, void *),
                    16
                );
                break;

            default:
                putc('%');
                putc(*format);
                break;
        }

        format++;
    }

    va_end(args);
}

int main() {
    printf("kernel successfully booted!\n");

    while (1) {
        
    }
    return 0;
}