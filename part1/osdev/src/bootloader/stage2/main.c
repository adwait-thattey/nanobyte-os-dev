#include <stdint.h>
#include "stdio.h"
#include "x86.h"
#include "disk.h"
#include "fat.h"
#include "memdefs.h"
#include "memory.h"

void* g_data = (void*)0x20000;

void puts_realmode(const char* str)
{
    while (*str) // String must be null terminated or we will crash
    {
        x86_realmode_putc(*str);
        ++str;
    }
}

void print_test_file(DISK disk);
void load_and_run_kernel(DISK disk);

uint8_t* KernelLoadBuffer = (uint8_t*)MEMORY_LOAD_KERNEL;
uint8_t* Kernel = (uint8_t*)MEMORY_KERNEL_ADDR;

// Define a new type KernelStart that is basically pointer to a function that takes no arguments and returns void
// equivalent to this in c++ >> using KernelStart = void(*)();
typedef void (*KernelStart)();

void __attribute__((cdecl)) start(uint16_t bootDrive)
{
    clrscr();

    // for( int i=0; i < 30; i++) {
    //     printf("Hello from Stage2 %d \n", i);
    // }
    uint8_t driveType;
    uint16_t cyls, secs, heads;

    bool ok = x86_Disk_GetDriveParams( (uint8_t)bootDrive, &driveType, &cyls, &secs, &heads);
    printf("ReadDiskParams return = %d , driveType = %u , cylinders = %lu , sectors = %lu , heads = %lu \n\n", ok, driveType, cyls, secs, heads);

    DISK disk;
    if (!DISK_Initialize(&disk, bootDrive))
    {
    printf("Disk init error\r\n");
    goto end;
    }

    if (!FAT_Initialize(&disk))
    {
        printf("FAT init error\r\n");
        goto end;
    }
    
    // print_test_file(disk);
    load_and_run_kernel(disk);

    // DISK_ReadSectors(&disk, 0, 1, g_data);
    // print_buffer("Boot sector: ", g_data, 512);

    // printf("Hello from stage2 protected mode\n");
    // puts_realmode("Hello from Real Mode\n");
    // printf("Hello again from stage2 pmode\n");
    // puts_realmode("Hello again from Real Mode\n");
end:
    for(;;);
}

void load_and_run_kernel(DISK disk)
{
    // load kernel
    FAT_File* fd = FAT_Open(&disk, "/kernel.bin");
    uint32_t read;
    uint8_t* kernelBuffer = Kernel;
    
    // start reading buffers of 0x10000 into 16 bit memory at 0x30000 and then copy that memory into kernel's starting point of 1MB (0x100000)
    while ((read = FAT_Read(&disk, fd, MEMORY_LOAD_SIZE, KernelLoadBuffer)))
    {
        memcpy(kernelBuffer, KernelLoadBuffer, read);
        kernelBuffer += read;
    }
    FAT_Close(fd);

    // reinterpret the kernel start memory address as the kernel function we defined earlier and then execute it
    KernelStart kernelStart = (KernelStart)Kernel;
    kernelStart();
}


void print_test_file(DISK disk)
{
        // browse files in root
    FAT_File* fd = FAT_Open(&disk, "/");
    FAT_DirectoryEntry entry;
    int i = 0;
    while (FAT_ReadEntry(&disk, fd, &entry) && i++ < 5)
    {
        printf("  ");
        for (int i = 0; i < 11; i++)
            putc(entry.Name[i]);
        printf("\r\n");
    }
    FAT_Close(fd);

    // read test.txt
    char buffer[100];
    uint32_t read;
    fd = FAT_Open(&disk, "mydir/test.txt");
    while ((read = FAT_Read(&disk, fd, sizeof(buffer), buffer)))
    {
        for (uint32_t i = 0; i < read; i++)
        {
            if (buffer[i] == '\n')
                putc('\r');
            putc(buffer[i]);
        }
    }
    FAT_Close(fd);
}


