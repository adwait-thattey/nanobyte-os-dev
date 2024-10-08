#pragma once
#include <stdint.h>

void putc(char c);
void puts(const char* str);
void clrscr();
void setcursor(int x, int y);

void printf(const char* fmt, ...);
void print_buffer(const char* msg, const void* buffer, uint32_t count);
