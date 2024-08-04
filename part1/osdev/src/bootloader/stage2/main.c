#include <stdint.h>
#include "stdio.h"
#include "x86.h"
//#include "disk.h"
//#include "fat.h"

//void far* g_data = (void far*)0x00500200;

void puts_realmode(const char* str)
{
    while (*str) // String must be null terminated or we will crash
    {
        x86_realmode_putc(*str);
        ++str;
    }
}

void __attribute__((cdecl)) start(uint16_t bootDrive)
{
    clrscr();

    // for( int i=0; i < 30; i++) {
    //     printf("Hello from Stage2 %d \n", i);
    // }

    printf("Hello from stage2 protected mode\n");
    puts_realmode("Hello from Real Mode\n");
    printf("Hello again from stage2 pmode\n");
    puts_realmode("Hello again from Real Mode\n");



    for(;;);
}
//    DISK disk;
//    if (!DISK_Initialize(&disk, bootDrive))
//    {
//        printf("Disk init error\r\n");
//        goto end;
//    }
//
//    DISK_ReadSectors(&disk, 19, 1, g_data);
//
//    if (!FAT_Initialize(&disk))
//    {
//        printf("FAT init error\r\n");
//        goto end;
//    }
//
//    // browse files in root
//    FAT_File far* fd = FAT_Open(&disk, "/");
//    FAT_DirectoryEntry entry;
//    int i = 0;
//    while (FAT_ReadEntry(&disk, fd, &entry) && i++ < 5)
//    {
//        printf("  ");
//        for (int i = 0; i < 11; i++)
//            putc(entry.Name[i]);
//        printf("\r\n");
//    }
//    FAT_Close(fd);
//
//    // read test.txt
//    char buffer[100];
//    uint32_t read;
//    fd = FAT_Open(&disk, "mydir/test.txt");
//    while ((read = FAT_Read(&disk, fd, sizeof(buffer), buffer)))
//    {
//        for (uint32_t i = 0; i < read; i++)
//        {
//            if (buffer[i] == '\n')
//                putc('\r');
//            putc(buffer[i]);
//        }
//    }
//    FAT_Close(fd);
//
//end:
//    for (;;);

