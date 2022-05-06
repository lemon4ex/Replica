//
//  MachOUtils.h
//  Replica
//
//  Created by h4ck on 18/11/1.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#ifndef MachOUtils_h
#define MachOUtils_h

#include <stdio.h>
#include <stdbool.h>

bool isBinaryDecrypted(const char *path);
bool isMachOBinary(const char *path);

#endif /* MachOUtils_h */
