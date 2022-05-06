//
//  VerifyCertView.m
//  Replica
//
//  Created by h4ck on 18/11/1.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import "VerifyCertView.h"
#import "unzip.h"
#import "OCSPManager.h"
#import "NSOpenPanel+Replica.h"
#import "ShellExecute.h"
#import "NSFileManager+Replica.h"

@interface VerifyCertView ()<NSTableViewDataSource,NSTableViewDelegate>
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSTextField *statusLabel;
@property (weak) IBOutlet NSButton *startButton;
@property (nonatomic) BOOL isProcessing;
@property (nonatomic) NSMutableArray *statusItemList;
@property (nonatomic) NSFileManager *fileManager;
@end

@implementation VerifyCertView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _statusItemList = [NSMutableArray array];
        _fileManager = [NSFileManager defaultManager];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        [self registerForDraggedTypes:@[NSFilenamesPboardType]];
    });
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _statusItemList.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (_statusItemList.count <= row) {
        return nil;
    }
    
    CertStatusItem *info = [_statusItemList objectAtIndex:row];
    NSTableCellView *cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    if ([tableColumn.identifier isEqualToString:@"colID"]) {
        cell.textField.stringValue = [@(row + 1) stringValue];
    }
    else if ([tableColumn.identifier isEqualToString:@"colName"])
    {
        cell.textField.stringValue = info.commonName;
    }
    else if ([tableColumn.identifier isEqualToString:@"colStatus"])
    {
        if (info.certStatus != CS_Good) {
            cell.textField.textColor = [NSColor redColor];
            cell.textField.stringValue = [NSString stringWithFormat:@"失效(%@)",info.certStatusToString];
        }
        else
        {
            cell.textField.textColor = [NSColor blackColor];
            cell.textField.stringValue = @"有效";
        }
    }
    else if ([tableColumn.identifier isEqualToString:@"colTime"])
    {
        if (info.certStatus != CS_Good) {
            cell.textField.stringValue = info.revokedTime;
        }
        else
        {
            cell.textField.stringValue = @"";
        }
    }
    else if ([tableColumn.identifier isEqualToString:@"colReason"])
    {
        if (info.certStatus != CS_Good) {
            cell.textField.stringValue = info.revocationReasonToString;
        }
        else
        {
            cell.textField.stringValue = @"";
        }
    }
    if (info.certStatus == 0) {
        cell.toolTip = [NSString stringWithFormat:@"证书：%@\n状态：有效",info.commonName];
    }
    else
    {
        cell.toolTip = [NSString stringWithFormat:@"证书：%@\n状态：失效(%@)\n失效时间：%@\n失效原因：%@",info.commonName,info.certStatusToString,info.revokedTime,info.revocationReasonToString];
    }
    return cell;
}


- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    do {
        NSPasteboard *pasteBoard = [sender draggingPasteboard];
        if ([[pasteBoard types]containsObject:NSFilenamesPboardType]) {
            NSArray *files = [pasteBoard propertyListForType:NSFilenamesPboardType];
            NSInteger numberOfFiles = [files count];
            if (numberOfFiles <= 0) {
                break;
            }
            NSString *filePath = [files objectAtIndex:0];
            [self checkCert:@[filePath]];
            return YES;
        }
    } while (0);
    
    return NO;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    if (_isProcessing) {
        return NSDragOperationNone;
    }
    
    do {
        NSPasteboard *pasteBoard = [sender draggingPasteboard];
        if ([[pasteBoard types]containsObject:NSFilenamesPboardType]) {
            NSArray *files = [pasteBoard propertyListForType:NSFilenamesPboardType];
            NSInteger numberOfFiles = [files count];
            if (numberOfFiles <= 0 || numberOfFiles > 1) {
                break;
            }
            NSString *filePath = [files objectAtIndex:0];
            NSString *pathExtension = [[filePath pathExtension]lowercaseString];
            if ([@[@"ipa",@"app",@"mobileprovision"] containsObject:pathExtension]) {
                return NSDragOperationCopy;
            }
        }
    } while (0);
    
    return NSDragOperationNone;
}

- (void)controlsEnabled:(BOOL)enabled{
    
    if (![NSThread isMainThread]){
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self controlsEnabled:enabled];
        });
    }
    else{
        _isProcessing = !enabled;
        _startButton.enabled = enabled;
    }
}

- (void)cleanup:(NSString *)tempFolder{
    NSLog(@"清理临时文件 %@",tempFolder);
    [_fileManager removeItemAtPath:tempFolder error:nil];
    [self controlsEnabled:YES];
}

- (void)setStatus:(NSString *)format,...
{
    if (![NSThread isMainThread]){
        va_list args;
        va_start(args, format);
        NSString *msg = [[NSString alloc]initWithFormat:format arguments:args];
        va_end(args);
        NSLog(@"%@",msg);
        dispatch_sync(dispatch_get_main_queue(), ^{
            _statusLabel.stringValue = msg;
        });
    }
    else{
        va_list args;
        va_start(args, format);
        NSString *msg = [[NSString alloc]initWithFormat:format arguments:args];
        va_end(args);
        NSLog(@"%@",msg);
        _statusLabel.stringValue = msg;
    }
}

- (IBAction)onStart:(id)sender
{
    NSString *desktopPath = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES)[0];
    [NSOpenPanel showOpenPanelModal:desktopPath message:@"选择需要检测到的文件或文件夹" fileTypes:@[@"ipa",@"app",@"mobileprovision"] multipleSelection:YES canChooseDirectories:YES canChooseFiles:YES canCreateDirectories:NO completionHandler:^(NSOpenPanel *panel, NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSMutableArray *inputPathList = [NSMutableArray array];
            for (NSURL *url in panel.URLs) {
                NSString *filePath = url.path;
                BOOL isDirectory;
                if (![[NSFileManager defaultManager]fileExistsAtPath:filePath isDirectory:&isDirectory]) {
                    NSLog(@"文件 %@ 不存在",filePath);
                    continue;
                }
                
                NSString *pathExtension = [[filePath pathExtension]lowercaseString];
                if (isDirectory && ![@[@"app"] containsObject:pathExtension]) {
                    NSArray *contents = [_fileManager contentsOfDirectoryAtPath:filePath error:nil];
                    for (NSString *name in contents) {
                        if (![@[@"ipa",@"app",@"mobileprovision"] containsObject:[[name pathExtension]lowercaseString]]) continue;
                        NSString *path = [filePath stringByAppendingPathComponent:name];
                        [inputPathList addObject:path];
                    }
                }
                [inputPathList addObject:url.path];
            }
            [self checkCert:inputPathList];
        }
    }];
}


- (void)checkCert:(NSArray *)filePathList
{
    [self setStatus:@"正在检查证书可用性..."];
    [self controlsEnabled:NO];
    [_statusItemList removeAllObjects];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSString *filePath in filePathList) {
            BOOL isDirectory;
            if (![[NSFileManager defaultManager]fileExistsAtPath:filePath isDirectory:&isDirectory]) {
                [self setStatus:@"文件 %@ 不存在",filePath];
                continue;
            }
            
            NSString *pathExtension = [[filePath pathExtension]lowercaseString];
            if (!isDirectory && ![@[@"ipa",@"mobileprovision"] containsObject:pathExtension]) {
                [self setStatus:@"文件类型不支持 %@",filePath];
                continue;
            }
            
            NSString *tempFolder = nil;
            NSString *embeddedPath = nil;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"Payload/.*?\\.app/embedded.mobileprovision" options:NSRegularExpressionCaseInsensitive error:nil];
            if ([@[@"ipa"] containsObject:pathExtension]) {
                tempFolder = [ShellExecute makeTempFolder];
                unzFile zip = unzOpen(filePath.fileSystemRepresentation);
                if (zip == NULL) {
                    NSLog(@"failed to open zip file");
                    return;
                }
                int ret = unzGoToFirstFile(zip);
                if (ret != UNZ_OK) {
                    NSLog(@"failed to go to first file");
                    return;
                }
                do {
                    ret = unzOpenCurrentFile(zip);
                    if (ret != UNZ_OK) {
                        NSLog(@"failed to open current file");
                        break;
                    }
                    unz_file_info fileInfo = {};
                    ret = unzGetCurrentFileInfo(zip, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
                    if (ret != UNZ_OK) {
                        NSLog(@"failed to retrieve info for file");
                        unzCloseCurrentFile(zip);
                        break;
                    }
                    char *filename = (char *)malloc(fileInfo.size_filename + 1);
                    unzGetCurrentFileInfo(zip, &fileInfo, filename, fileInfo.size_filename + 1, NULL, 0, NULL, 0);
                    filename[fileInfo.size_filename] = '\0';
                    NSString *file = [NSString stringWithUTF8String:filename];
                    if ([regex numberOfMatchesInString:file options:0 range:NSMakeRange(0, file.length)] > 0) {
                        char *buffer = calloc(1, fileInfo.uncompressed_size);
                        unzReadCurrentFile(zip, buffer, fileInfo.uncompressed_size);
                        NSData *data = [NSData dataWithBytesNoCopy:buffer length:fileInfo.uncompressed_size freeWhenDone:YES];
                        embeddedPath = [tempFolder stringByAppendingPathComponent:file.lastPathComponent];
                        [data writeToFile:embeddedPath atomically:YES];
                        unzCloseCurrentFile(zip);
                        break;
                    }
                    free(filename);
                    unzCloseCurrentFile(zip);
                } while (unzGoToNextFile(zip) == UNZ_OK);
                unzClose(zip);
            }
            else if ([pathExtension isEqualToString:@"mobileprovision"])
            {
                embeddedPath = filePath;
            }
            else
            {
                embeddedPath = [filePath stringByAppendingPathComponent:@"embedded.mobileprovision"];
            }
            
            if ([[NSFileManager defaultManager]fileExistsAtPath:embeddedPath]) {
                [[OCSPManager share]checkRevocationWtihPath:[@"file:///" stringByAppendingString:embeddedPath] completeHandle:^(CertStatusItem *statusItem, NSError *error) {
                    if (error) {
                        NSLog(@"查询证书状态失败，%@",error.description);
                        return;
                    }
                    [_statusItemList addObject:statusItem];
                }];
            }
            else
            {
                NSLog(@"未找到可用的 embedded.mobileprovision 文件");
            }
            
            if (tempFolder) {
                [self cleanup:tempFolder];
                tempFolder = nil;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_tableView reloadData];
            [self controlsEnabled:YES];
            [self setStatus:@"检查完成，共检查 %lu 个描述文件",(unsigned long)_statusItemList.count];
        });
    });
    
}

@end
