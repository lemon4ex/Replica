//
//  MachOUtils.c
//  Replica
//
//  Created by h4ck on 18/11/1.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#include "MachOUtils.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <mach-o/fat.h>
#include <mach-o/swap.h> // 大小端交换函数在此
#include <mach-o/getsect.h> // 获取区段相关数据的接口
#include <objc/runtime.h>
#include <objc/message.h>
#include <sys/mman.h>
#include <unistd.h>

// 可以使用mach-o/swap.h里的函数替代
static uint32_t swap32(uint32_t value,uint32_t magic)
{
    if (magic == FAT_CIGAM || magic == MH_CIGAM || magic == MH_CIGAM_64) {
        return ((value & 0xFF000000) >> 24) | ((value & 0x00FF0000) >> 8) | ((value & 0x0000FF00) << 8) | ((value & 0x000000FF) << 24);
    }
    return value;
}

/**
 *  判断某个arch是否已经被破解(解密)，已破解返回true，否则返回false
 */
static bool isArchDecrypted(void *base_addr)
{
    struct mach_header *mach_header = (struct mach_header *)base_addr;
    // 只处理MH_MAGIC_64类型，其他类型自行处理，注意数据大小端和32/64位程序的头结构体不同。如果是MH_CIGAM的格式，需要注意读取数据时，需将结构体头的数据进行转换（Swap32）才能使用
    // __PAGEZERO里的 vmaddr+vmsize = 虚拟地址的基址，其他地方的 虚拟地址 - 虚拟地址的基址 = 文件偏移
    if (mach_header->magic == MH_MAGIC_64 || mach_header->magic == MH_CIGAM_64) {
        struct mach_header_64 *mach_header_64 = (struct mach_header_64 *)mach_header;
        struct load_command *load_cmd = (struct load_command *)(mach_header_64 + 1);
        uint32_t ncmds = swap32(mach_header->ncmds,mach_header->magic);
        for (uint32_t i = 0; i < ncmds; ++i) {
            uint32_t cmd = swap32(load_cmd->cmd,mach_header->magic);
            if (cmd == LC_ENCRYPTION_INFO_64) {
                struct encryption_info_command_64 *encryption_info_64 = (struct encryption_info_command_64 *)load_cmd;
                uint32_t cryptid = swap32(encryption_info_64->cryptid,mach_header->magic);
                return cryptid == 0;
            }
            uint32_t cmd_size = swap32(load_cmd->cmdsize,mach_header->magic);
            load_cmd = (struct load_command *)((char *)load_cmd + cmd_size);
        }
    }
    else if(mach_header->magic == MH_MAGIC || mach_header->magic == MH_CIGAM)
    {
        struct load_command *load_cmd = (struct load_command *)(mach_header + 1);
        uint32_t ncmds = swap32(mach_header->ncmds,mach_header->magic);
        
        for (uint32_t i = 0; i < ncmds; ++i) {
            uint32_t cmd = swap32(load_cmd->cmd,mach_header->magic);
            if (cmd == LC_ENCRYPTION_INFO) {
                struct encryption_info_command *encryption_info_64 = (struct encryption_info_command *)load_cmd;
                uint32_t cryptid = swap32(encryption_info_64->cryptid,mach_header->magic);
                return cryptid == 0;
            }
            uint32_t cmd_size = swap32(load_cmd->cmdsize,mach_header->magic);
            load_cmd = (struct load_command *)((char *)load_cmd + cmd_size);
        }
    }
    return true;
}

bool isMachOBinary(const char *path)
{
    int fd = open(path, O_RDWR);
    if (fd == -1) {
        return false;
    }
    bool isBin = false;
    
    do {
        struct stat stat;
        fstat(fd, &stat);
        if (stat.st_size < sizeof(uint32_t)) {
            break;
        }
        
        uint32_t magic;
        read(fd, &magic, sizeof(magic));
        if (magic == FAT_CIGAM || magic == MH_CIGAM || magic == MH_CIGAM_64||
            magic == FAT_MAGIC || magic == MH_MAGIC || magic == MH_MAGIC_64) {
            isBin = true;
        }
    } while (0);
    close(fd);
    return isBin;
}

/**
 * 判断二进制文件是否被破解(解密)，已破解返回true，否则返回false
 */
bool isBinaryDecrypted(const char *path)
{
    int fd = open(path, O_RDWR);
    if (fd == -1) {
        return true;
    }
    bool isDecrypted = true;
    do {
        struct stat stat;
        fstat(fd, &stat);
        if (stat.st_size < sizeof(uint32_t)) {
            break;
        }
        
        uint32_t magic;
        read(fd, &magic, sizeof(magic));
        if (magic == FAT_CIGAM || magic == MH_CIGAM || magic == MH_CIGAM_64||
            magic == FAT_MAGIC || magic == MH_MAGIC || magic == MH_MAGIC_64) {
            void *base = mmap(0, stat.st_size, PROT_READ|PROT_WRITE, MAP_FILE|MAP_SHARED, fd, 0);
            uint32_t magic = (*(uint32_t *)base);
            if(magic == FAT_MAGIC || magic == FAT_CIGAM)
            {
                struct fat_header *fat_header = (struct fat_header *)base;
                uint32_t archs = swap32(fat_header->nfat_arch,fat_header->magic);
                for (uint32_t i = 0; i < archs; ++i) {
                    struct fat_arch *arch = (struct fat_arch *)((char *)base + sizeof(struct fat_header) + sizeof(struct fat_arch) * i);
                    uint32_t offset = swap32(arch->offset,magic);
                    isDecrypted = isArchDecrypted((char *)base + offset);
                    if(!isDecrypted) break;
                }
            }
            else
            {
                isDecrypted = isArchDecrypted(base);
            }
            munmap(base, stat.st_size);
        }
    } while (0);
    close(fd);
    
    return isDecrypted;
}
