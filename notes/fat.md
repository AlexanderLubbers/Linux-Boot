# FAT file system

what the disk looks like under the fat32 file system:

```
FAT32 volume
┌──────────────────────────────────────┐
│ Reserved Region                      │
│  ├─ Boot Sector (sector 0)           │
│  ├─ FSInfo sector                    │
│  └─ Other reserved sectors           │
├──────────────────────────────────────┤
│ FAT #1                               │
├──────────────────────────────────────┤
│ FAT #2                               │
├──────────────────────────────────────┤
│ Data Region                          │
│  ├─ Root Directory                   │
│  ├─ Subdirectories                   │
│  └─ Files                            │
└──────────────────────────────────────┘
```

In the reserved region, there is data that indicates how many sectors are reserved

To get the fat region size, look in the file allocation table and then look at the FAT count and the number of sectors per FAT

sectors are grouped into clusters

the reserved region contains info describing the file system

in the reserved region contains the boot sector and the BIOS parameter block.

the BIOS parameter block contains parameters to describe the file system like:
```
bytes per sector
sectors per cluster
number of reserved sectors
number of FATs
size of each FAT
total sectors
root directory starting cluster
location of the FSInfo sector
```

FSinfo block which is also in the reserved region caches free space metrics to avoid having to scan the entire FAT

FAT does two jobs, it records what clusters are in use as well as telling what cluster comes next. This means that under FAT32 files do not need to be continuous

FAT 2 is typically just a backup of FAT 1 incase FAT 1 gets corrupted

FAT32 entry typically occupies 32 bits, but only 28 bits are used. The other 4 are reserved

FAT has multiple entries and each entry presents information about the cluster (for example: FAT[100] = 105. next cluster is 105)

FAT entries 0 and 1 are reserved

root directory starts at cluster 2. This cluster contains directory data and the directory data is composed of a bunch of directory entries
```
Directory Entry
├── Name
├── Attributes
├── Timestamps
├── Starting cluster
└── File size
```

The Directory Entry answers the question of what is this file and where does it start while FAT answers the question of where does this file continue

The process for finding a file:

```
example directory entry
┌─────────────────────────────┐
│ Name: KERNEL.ELF            │
│ Attributes: ...             │
│ Timestamps: ...             │
│ Starting cluster: 100       │
│ File size: 183000 bytes     │
└─────────────────────────────┘ 
```

final design idea:
```
Disk
┌──────────────────────────────┐
│ Boot code / boot area        │
│                              │
│ Stage 1                      │
│ Stage 2                      │
├──────────────────────────────┤
│ FAT32 volume                 │
│                              │
│ Reserved region              │
│ FAT #1                       │
│ FAT #2                       │
│ Data region                  │
│   ├── KERNEL.ELF             │
│   ├── BOOT.CFG               │
│   └── ...                    │
└──────────────────────────────┘
```