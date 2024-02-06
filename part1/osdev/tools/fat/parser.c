
#include <ctype.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

typedef u_int8_t bool ;
#define false   0
#define true    1

#define IS_OK(x)    (x==true)
#define RETURN_ON_NOTOK(x, ret)  if(!IS_OK(x)){return ret;}

typedef struct {
  
    uint8_t     boot_jump_instructioni[3];   
    uint8_t     bpb_oem[8];				    
    uint16_t    bpb_bytes_per_sector;       
    uint8_t     bpb_sectors_per_cluster;	
    uint16_t    bpb_n_reserved_clusters;	
    uint8_t     bpb_fat_count;			    
    uint16_t    bpb_root_dir_count;			
    uint16_t    bpb_total_sectors;		    
    uint8_t     bpb_media_storage_des;		
    uint16_t    bpb_sectors_per_fat;		
    uint16_t    bpb_sectors_per_track;		
    uint16_t    bpb_sides_on_media;			
    uint8_t     bpb_hidden_sectors[4];			
    uint8_t     bpb_large_sector_count[4];	
    
    // Extended boot record
    
    uint8_t     ebr_drive_number;           			
    uint8_t     ebr_win_flag;				
    uint8_t     ebr_sig;					
    uint8_t     ebr_vol_id[4];				
    uint8_t     ebr_vol_label[11];			
    uint8_t     ebr_system_id[8];			

} __attribute__((packed)) BootSector;

#define DIR_NAME_BASE_LEN   11
typedef struct {
    
    uint8_t     name[DIR_NAME_BASE_LEN];
    uint8_t     attributes;
    uint8_t     _reserved;
    uint8_t     createTimeTenths;
    uint16_t    createTime;
    uint16_t    createDate;
    uint16_t    lastAccessedDate;
    uint16_t    firstClusterNumber;
    uint16_t    lastModificationTime;
    uint16_t    lastModificationDate;
    uint16_t    firstClusterLow;
    uint32_t    size;

} __attribute__((packed)) DirectoryStructure;

BootSector g_BootSector;
uint8_t* g_FAT = NULL;  // this is 8 bit integer. But each FAT12 entry is 12 bits. Thus 1.5 of each is going to corrospond to a FAT entry. This is relevant in readFIle function below
DirectoryStructure* g_rootEntry = NULL;
uint32_t g_RootDirectoryEnd = 0;

bool readBootSector(FILE* disk)
{
    // boot sector is at the begining of the disk
    long int curpos = ftell(disk);
    rewind(disk);
    bool ok = fread( &g_BootSector, sizeof(BootSector),1, disk) > 0;
    fseek(disk, curpos, SEEK_SET);

    return ok;
}

bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* out_buffer)
{
    long int curpos = ftell(disk);
    bool ok = true;

    printf("DEBUG: Reading [%u] sectors at sector_offset [%d]\n", count, lba);
    ok = ok && ( fseek(disk, lba* g_BootSector.bpb_bytes_per_sector, SEEK_SET) == 0);
    ok = ok && ( fread(out_buffer,g_BootSector.bpb_bytes_per_sector, count, disk) > 0);
    fseek(disk, curpos, SEEK_SET);

    return ok;
}

bool readRootDirectory(FILE* disk)
{
    // root dir starts after reserved sectors and file allocation tables

    /*
     * There can be multiple entries (file/folder) in the root directory
     * bpb_root_dir_count gives count of how many such files/folders are present
     * Each of them would be an object of type DirectoryStructure
     * SO find out how many such objects are there and get size to be read in bytes. 
     * Then convert this into number of sectors to be read and read them into g_rootEntry pointer. 
     * Now g_rootENtry is effectively an array with each element referring to each file/folder in root
    */
    uint32_t lba = (g_BootSector.bpb_n_reserved_clusters*g_BootSector.bpb_sectors_per_cluster) + (g_BootSector.bpb_sectors_per_fat*g_BootSector.bpb_fat_count);
    uint32_t sizeInBytes = sizeof(DirectoryStructure)*g_BootSector.bpb_root_dir_count;
    uint32_t sizeInSectors = sizeInBytes/g_BootSector.bpb_bytes_per_sector;
    if(sizeInBytes % g_BootSector.bpb_bytes_per_sector > 0) {
        ++sizeInSectors;
    }

    g_rootEntry = (DirectoryStructure*) malloc(sizeInSectors*g_BootSector.bpb_bytes_per_sector);

    g_RootDirectoryEnd = lba + sizeInSectors;
    return readSectors(disk,lba, sizeInSectors, g_rootEntry);
}

bool readFAT(FILE* disk)
{
    g_FAT = (uint8_t*) malloc(g_BootSector.bpb_sectors_per_fat * g_BootSector.bpb_bytes_per_sector);
    if(!g_FAT)
    {
        printf("Failed to allocate memory for FAT \n");
        return false;
    }

    bool ok = true;
    ok = readSectors(disk, g_BootSector.bpb_n_reserved_clusters*g_BootSector.bpb_sectors_per_cluster, g_BootSector.bpb_sectors_per_fat ,g_FAT);
    return ok;
}

DirectoryStructure* findFileInRoot(const char* name)
{
    for(uint32_t i = 0; i < g_BootSector.bpb_root_dir_count; ++i)
    {
        if(memcmp(g_rootEntry[i].name, name, DIR_NAME_BASE_LEN) == 0)
        {
            return &g_rootEntry[i];
        }
           
    }

    return NULL;
}

bool readFile(DirectoryStructure* fileEntry, FILE* disk, uint8_t* outputBuffer)
{
    if(!fileEntry || !disk)
        return false;

    /* the first cluster is pointed to by the FirstClusterLow field in the record
     * (FirstClusterLow tells the lower 16 bits of cluster, FirstClusterHigh the higher 16 bits. But since this is FAT12, cluster numbers would be limited to 12 bits. 
     * Hence HighClusterNumber always remains 0
     *
     * Given a cluster, how to find the next cluster in chain?
     * For this we need the FAT table. 
     * To find the next cluster, we need to go to the FAT entry for the current cluster. 
     * This entry will contain the cluster number for the next cluster.
     * CLuster numbers are always lower than 0xFF8. So a number greater than or equal to 0xFF8 in the FAT entry indicates the end of cluster chain, i.e. last file block has been reached.
     * So how to find the FAT entry for a cluster?
     * THere is significant complexity involved here due to the nature of how little endian bytes are stored and each entry being 12 bits
     * Taken from here: https://wiki.osdev.org/FAT#FAT_12_2
     * For example, 2 consequently FAT entries with values 0x123 and 0x456 when stored in the HEX table would be stored as 23 61 45
     * WHy? because least significant bytes are stored first in little endian. 23 is the least significant byte of 0x123, thus stored first
     * Then 1 gets combined with 6 to form next byte then 45 is the most significant byte
     *
     * SO how to mitigate this?
     * If we read 23 61 45 as a 16 bit little endian number, we would get values 0x6123 and 0x4561
     * To recover )x123 from 1st, we discard the first 4 bits (0x6) and to recover 0x456 from 2nd number, we discard last 4 bits (0x1)
     *
     * Thus to read the next cluster in chain, we go to location floor(cluster_number*1.5) index in the FAT table and read 16 bits. 
     * Then if the cluster number was even, we discard the first 4 bits 
     * If the cluster number was odd, we discard the last 4 bits
     *

 */

    uint16_t currentCluster = fileEntry->firstClusterLow; // this is the first cluster

    // read current cluster, then find the next cluster and keep reading until we find the end of cluster chain
    bool ok = true;
    do
    {
        // first 2 clusters are part of reserved. 
        uint32_t lba = g_RootDirectoryEnd + (currentCluster - 2)*g_BootSector.bpb_sectors_per_cluster;
        ok = ok && readSectors(disk, lba, g_BootSector.bpb_sectors_per_cluster, outputBuffer);

        // move outputBuffer pointer ahead so that we can read next cluster
        outputBuffer += (g_BootSector.bpb_sectors_per_cluster*g_BootSector.bpb_bytes_per_sector);

        uint32_t fatIndex = currentCluster + currentCluster/2;
        // first read 16 bits here then decide where to remove left 4 bits or right 4 bits
        uint16_t nextCluster = *( (uint16_t*)(g_FAT + fatIndex) );
        
        if(currentCluster%2)
        {
            // remove upper 4 bits
            nextCluster = nextCluster >> 4;
        }
        else {
            // remove lower 4 bits
            nextCluster = nextCluster & 0x0FFF;
        }

        currentCluster = nextCluster;
    }while(ok && currentCluster < 0xFF8);

    return ok;

}

int main(int argc, char** argv)
{
    if(argc < 3)
    {
        printf("Usage: %s <disk_image> <file_name> \n", argv[0]);
        return -1;
    }

    printf("DEBUG: Args: %s %s \n", argv[1], argv[2]);

    FILE* disk = fopen(argv[1], "rb");
    if(disk == NULL)
    {
        printf("Failed to open and read disk [%s] \n", argv[1]);
        return -1;
    }

    bool ok = true;
    ok = readBootSector(disk);
    if(!IS_OK(ok)) 
    {
        printf("Unable to read boot record \n");
        return -1;
    }

    ok = readFAT(disk);
    if(!IS_OK(ok))
    {
        printf("Unable to read FAT OK = [%d]\n", ok);
        free(g_FAT);
        return -1;
    }

    ok = readRootDirectory(disk);
    if(!IS_OK(ok)) {
        printf("Unable to read Root dirs \n");
        free(g_FAT);
        free(g_rootEntry);
        return -1;
    }

    DirectoryStructure* fileEntry = findFileInRoot(argv[2]);
    if(fileEntry == NULL)
    {
        printf("Unable to find file %s in the image \n", argv[2]);
    }

    uint8_t* buffer = (uint8_t*)malloc(fileEntry->size + g_BootSector.bpb_bytes_per_sector); // allocate extra sector of memory to avoid seg faults;
    //memset(buffer, 0, fileEntry->size + g_BootSector.bpb_bytes_per_sector);

    ok = readFile(fileEntry, disk, buffer);
    if(!IS_OK(ok))
    {   
        printf("COuld not read file contents");
        free(buffer);
        free(g_FAT);
        free(g_rootEntry);
        return -1;
    }
    
    printf("File contents are : \n");
    // print the file
    for(size_t i = 0; i < fileEntry->size; ++i)
    {
        if(isprint(buffer[i]))
            printf("%c", (char)buffer[i]);
        else
            printf("<%02x>", buffer[i]);
    }

    free(g_FAT);
    free(g_rootEntry);
    return 0;
}









