
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
uint8_t* g_FAT = NULL;
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

    uint32_t lba = (g_BootSector.bpb_n_reserved_clusters*g_BootSector.bpb_sectors_per_cluster) + (g_BootSector.bpb_sectors_per_fat*g_BootSector.bpb_fat_count);
    uint32_t sizeInBytes = sizeof(DirectoryStructure)*g_BootSector.bpb_root_dir_count;
    uint32_t sizeInSectors = sizeInBytes/g_BootSector.bpb_bytes_per_sector;
    if(sizeInBytes % g_BootSector.bpb_bytes_per_sector > 0) {
        ++sizeInBytes;
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
        Then the cluster chain begins. 
        Here is how the cluster chain is organized
        FAT table indicates the status and location of all clusters on the disk
        FAT12 uses 12 bits to address the clusters on the disk. Each 12 bit entry in the FAT points to the next cluster for a file
    
        Given a current cluster, how to find the next cluster ?
        offset to FAT table = current_cluster current_cluster/2  (current cluster * 1.5)

        fat_sector + first_fat_sector + (fat_offset/size_of_sector)

        Now we know the required data is 12 bits wide. We read 2 sectors at this point from fat_Sector
        2 sectors is 16 bits, but FAT record is only 12 bits
        If Current cluster is even (0,2,4...) means we need to discard the left most 4 bits
        If current cluster is odd (1,3,5...) means we need to discard the right most 4 bits

 */

    uint16_t currentCluster = fileEntry->firstClusterLow; // this is the first cluster

    // read current cluster, then find the next cluster and keep reading until we find the end of cluster chain
    bool ok = true;
    do
    {
        // first 2 clusters are part of reserved. 
        uint32_t lba = g_RootDirectoryEnd + (currentCluster - 2)*g_BootSector.bpb_sectors_per_cluster;
        ok = ok && readSectors(disk, lba, g_BootSector.bpb_sectors_per_cluster, outputBuffer);
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









