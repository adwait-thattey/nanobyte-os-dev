use std::env;


// Structure for the init boot records

struct BootSector {
  
    boot_jump_instruction:      [i8;3], 
    bpb_oem:				    [i8;8],
    bpb_bytes_per_sector:       [i8;2],
    bpb_sectors_per_cluster:	[i8;1],
    bpb_n_reserved_clusters:	[i8;2],
    bpb_fat_count:			    [i8;2],
    bpb_root_dir_count:			[i8;2],
    bpb_total_sectors:		    [i8;2],
    bpb_media_storage_des:		[i8;1],
    bpb_sectors_per_fat:		[i8;2],
    bpb_sectors_per_track:		[i8;2],
    bpb_sides_on_media:			[i8;2],
    bpb_hidden_sectors:		    [i8;4],	
    bpb_large_sector_count:		[i8;4],
    
    // Extended boot record
    
    ebr_drive_number:           [i8;1],			
    ebr_win_flag:				[i8;1],
    ebr_sig:					[i8;1],
    ebr_vol_id:					[i8;4],
    ebr_vol_label:			    [i8;11],
    ebr_system_id:			    [i8;8],

}

fn main() {
    
    let args: Vec<String> =env::args().collect();
    
    if args.len() < 3 {
        println!("Usage: {} <disk image> <file name>", args[0]);
    }
    
    println!("All args: {:?}", args);

    println!("Size of BootSector struct is {} bytes", std::mem::size_of::<BootSector>());
}
