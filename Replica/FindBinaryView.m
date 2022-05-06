//
//  FindBinaryView.m
//  Replica
//
//  Created by h4ck on 18/11/1.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import "FindBinaryView.h"
#import "NSFileManager+Replica.h"
#import "MachOUtils.h"
#import "NSOpenPanel+Replica.h"
#import "SSZipArchive.h"
#import "ShellExecute.h"

@implementation BinaryInfo

@end

@interface FindBinaryView ()<NSTableViewDataSource,NSTableViewDelegate>
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSTextField *statusLabel;
@property (weak) IBOutlet NSButton *startButton;
@property (nonatomic) BOOL isProcessing;
@property (nonatomic) NSMutableArray *binaryInfoList;
@property (nonatomic) NSFileManager *fileManager;
//@property (nonatomic) NSMutableArray *inputPathList;
@end

@implementation FindBinaryView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _fileManager = [NSFileManager defaultManager];
        _binaryInfoList = [NSMutableArray array];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        [self registerForDraggedTypes:@[NSFilenamesPboardType]];
    });
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _binaryInfoList.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (_binaryInfoList.count <= row) {
        return nil;
    }
    
    BinaryInfo *info = [_binaryInfoList objectAtIndex:row];
    NSTableCellView *cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    if ([tableColumn.identifier isEqualToString:@"colID"]) {
        cell.textField.stringValue = [@(row + 1) stringValue];
    }
    else if ([tableColumn.identifier isEqualToString:@"colDecrypted"])
    {
        cell.textField.stringValue = info.isDecrypted?@"是":@"否";
        if (!info.isDecrypted) {
            cell.textField.textColor = [NSColor redColor];
        }else{
            cell.textField.textColor = [NSColor blackColor];
        }
    }
    else if ([tableColumn.identifier isEqualToString:@"colSize"])
    {
        cell.textField.stringValue = [self fileSizeWithInterge:info.size];
    }
    else if ([tableColumn.identifier isEqualToString:@"colPath"])
    {
        cell.textField.stringValue = info.path;
    }
    cell.toolTip = info.path;
    return cell;
}

// 计算文件大小
- (NSString *)fileSizeWithInterge:(long long)size {
    // 1k = 1024, 1m = 1024k
    if (size < 1024) {
        // 小于1k
        return [NSString stringWithFormat:@"%ldB",(long)size];
    }else if (size < 1024 * 1024){
        // 小于1m
        CGFloat aFloat = size/1024.f;
        return [NSString stringWithFormat:@"%.2fKB",aFloat];
    }else if (size < 1024 * 1024 * 1024){
        // 小于1G
        CGFloat aFloat = size/(1024 * 1024.f);
        return [NSString stringWithFormat:@"%.2fMB",aFloat];
    }else{
        CGFloat aFloat = size/(1024*1024*1024.f);
        return [NSString stringWithFormat:@"%.2fGB",aFloat];
    }
}

- (void)findBinary:(NSArray *)filePathList{
    [self setStatus:@"二进制文件查找中..."];
    [self controlsEnabled:NO];
    [_binaryInfoList removeAllObjects];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSString *filePath in filePathList) {
            BOOL isDirectory;
            if (![[NSFileManager defaultManager]fileExistsAtPath:filePath isDirectory:&isDirectory]) {
                [self setStatus:@"文件 %@ 不存在",filePath];
                continue;
            }
            
            NSString *pathExtension = [[filePath pathExtension]lowercaseString];
            if (!isDirectory && ![@[@"ipa"] containsObject:pathExtension]) {
                [self setStatus:@"不支持的文件类型 %@",filePath];
                continue;
            }
            
            NSString *tempFolder = nil;
            NSString *workingDirectory = filePath;
            if ([@[@"ipa"] containsObject:pathExtension]) {
                tempFolder = [ShellExecute makeTempFolder];
                workingDirectory = [tempFolder stringByAppendingPathComponent:@"out"];
                if (![SSZipArchive unzipFileAtPath:filePath toDestination:workingDirectory]) {
                    [self setStatus:@"解压 ipa 文件失败"];
                    continue;
                }
            }

            [NSFileManager recursiveDirectorySearch:workingDirectory findRuleBlock:^BOOL(NSString *path, BOOL isDirectory) {
                if (!isDirectory) {
                    return isMachOBinary(path.UTF8String);
                }
                return NO;
            } foundFileBlock:^BOOL(NSString *path, BOOL isDirectory) {
                BinaryInfo *info = [[BinaryInfo alloc]init];
                NSString *shortPath = [path stringByReplacingOccurrencesOfString:workingDirectory withString:@""];
                info.path = [shortPath stringByReplacingOccurrencesOfString:@"/Payload" withString:@""];
                info.size = [[NSFileManager defaultManager]attributesOfItemAtPath:path error:nil].fileSize;
                info.isDecrypted = isBinaryDecrypted(path.UTF8String);
                [_binaryInfoList addObject:info];
                [self setStatus:@"找到二进制文件 %@",info.path];
                return YES;
            }];
            
            if (tempFolder) {
                [self cleanup:tempFolder];
                tempFolder = nil;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_tableView reloadData];
            [self controlsEnabled:YES];
            [self setStatus:@"查找完成，共找到 %lu 个二进制文件",(unsigned long)_binaryInfoList.count];
        });
    });
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
            [self findBinary:@[filePath]];
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
            if ([@[@"ipa",@"app"] containsObject:pathExtension]) {
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
    [NSOpenPanel showOpenPanelModal:desktopPath message:@"选择需要查找二进制的文件或文件夹" fileTypes:@[@"ipa",@"app"] multipleSelection:YES canChooseDirectories:YES canChooseFiles:YES canCreateDirectories:NO completionHandler:^(NSOpenPanel *panel, NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSMutableArray *inputPathList = [NSMutableArray array];
            for (NSURL *url in panel.URLs) {
                [inputPathList addObject:url.path];
            }
            [self findBinary:inputPathList];
        }
    }];
}
@end
