//
//  ResignView.m
//  Replica
//
//  Created by h4ck on 18/11/1.
//  Copyright © 2018年 字节时代（https://byteage.com） All rights reserved.
//

#import "ResignView.h"
#import "MachOUtils.h"
#import "ShellExecute.h"
#import "SigningIdentity.h"
#import "Provisioning.h"
#import "NSOpenPanel+Replica.h"
#import "NSSavePanel+Replica.h"
#import "NSFileManager+Replica.h"
#import "SSZipArchive.h"
#import "operations.h"
#import "headers.h"

#include <sys/stat.h>

@implementation OutputInfo

@end


@interface ResignView ()
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSTextField *entitlementField;
@property (weak) IBOutlet NSTextField *bundleIDField;
@property (weak) IBOutlet NSTextField *displayNameField;
@property (weak) IBOutlet NSTextField *bundleVersionField;
@property (weak) IBOutlet NSTextField *shortVersionField;
@property (weak) IBOutlet NSTextField *urlSchemeField;
@property (weak) IBOutlet NSTextField *extraFileField;
@property (weak) IBOutlet NSTextField *scriptFileField;
@property (weak) IBOutlet NSPopUpButton *provisioningProfilesPopup;
@property (weak) IBOutlet NSPopUpButton *codesigningCertsPopup;

@property (weak) IBOutlet NSButton *selectInputButton;
@property (weak) IBOutlet NSButton *refreshCertButton;
@property (weak) IBOutlet NSButton *openProvisonButton;
@property (weak) IBOutlet NSButton *selectEntitlementButton;
@property (weak) IBOutlet NSButton *selectScriptButton;
@property (weak) IBOutlet NSButton *createScriptButton;
@property (weak) IBOutlet NSButton *startSignButton;

@property (weak) IBOutlet NSButton *packIPAOption;
@property (weak) IBOutlet NSButton *checkDecryptedOption;
@property (weak) IBOutlet NSButton *disableASLROption;
@property (weak) IBOutlet NSButton *removeRestrictOption;
@property (weak) IBOutlet NSButton *enhancedModeOption;

@property (weak) IBOutlet NSTextField *statusLabel;

@property (nonatomic) NSMutableDictionary<NSString *, NSArray<Provisioning *> *> *provisioningMap;
@property (nonatomic) NSMutableArray<SigningIdentity *> *keychainsIdentities;
@property (nonatomic) NSMutableArray *inputPathList;
@property (nonatomic) OutputInfo *outputInfo;
@property (nonatomic) BOOL isProcessing;
@property (nonatomic) NSFileManager *fileManager;

@property (nonatomic) SigningIdentity *signingIdentity;
@property (nonatomic) Provisioning *provisioningFile;
@property (nonatomic) NSString *applicationID;
@property (nonatomic) NSString *displayName;
@property (nonatomic) NSString *shortVersion;
@property (nonatomic) NSString *bundleVersion;
@property (nonatomic) NSString *entitlementPlistFile;
@property (nonatomic) NSArray *specificFiles;
@property (nonatomic) NSArray *urlSchemes;
@property (nonatomic) NSString *scriptFile;

@property (nonatomic) BOOL packIPA;
@property (nonatomic) BOOL checkDecrypted;
@property (nonatomic) BOOL disableASLR;
@property (nonatomic) BOOL removeRestrict;
@property (nonatomic) BOOL enhancedMode;

@property (nonatomic) dispatch_semaphore_t semaphore; ///< 同步信号量
@property (nonatomic) BOOL ignoreWarning; ///< 忽略警告
@end

@implementation ResignView

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
        [self registerForDraggedTypes:@[NSFilenamesPboardType]];
        [self loadProvisionAndIdentityList];
    });
}

- (void)loadProvisionAndIdentityList{
    [_provisioningProfilesPopup removeAllItems];
    [_codesigningCertsPopup removeAllItems];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            [self initProvisionAndIdentityList];
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
            formatter.dateStyle = NSDateFormatterShortStyle;
            formatter.timeStyle = NSDateFormatterMediumStyle;
            
            SigningIdentity *signingIdentity = [self.keychainsIdentities firstObject];
            if (!signingIdentity) {
                return;
            }
            NSArray *matchedProvisions = [self.provisioningMap objectForKey:signingIdentity.serial];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.keychainsIdentities enumerateObjectsUsingBlock:^(SigningIdentity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    [_codesigningCertsPopup addItemWithTitle:obj.commonName];
                }];
                
                [matchedProvisions enumerateObjectsUsingBlock:^(Provisioning * _Nonnull provision, NSUInteger idx, BOOL * _Nonnull stop) {
                    [_provisioningProfilesPopup addItemWithTitle:[NSString stringWithFormat:@"%@ (%@)",provision.name,provision.teamID]];
                    NSString *createDate = [formatter stringFromDate:provision.creationDate];
                    NSString *expiredDate = [formatter stringFromDate:provision.expirationDate];
                    _provisioningProfilesPopup.lastItem.toolTip = [NSString stringWithFormat:@"%@\n\nTeam ID: %@\nCreated: %@\nExpires: %@\nStatus: %@",provision.name,provision.teamID,createDate,expiredDate,provision.status];
                }];
            });
        }
    });
}

- (IBAction)onPopUpButtonSelect:(NSPopUpButton *)sender{
    if ([sender isEqual:_codesigningCertsPopup]) {
        SigningIdentity *signingIdentity = [self.keychainsIdentities objectAtIndex:sender.indexOfSelectedItem];
        NSArray *provisions = [self.provisioningMap objectForKey:signingIdentity.serial];
        [_provisioningProfilesPopup removeAllItems];
        NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterMediumStyle;
        [provisions enumerateObjectsUsingBlock:^(Provisioning * _Nonnull provision, NSUInteger idx, BOOL * _Nonnull stop) {
            [_provisioningProfilesPopup addItemWithTitle:[NSString stringWithFormat:@"%@ (%@)",provision.name,provision.teamID]];
            NSString *createDate = [formatter stringFromDate:provision.creationDate];
            NSString *expiredDate = [formatter stringFromDate:provision.expirationDate];
            _provisioningProfilesPopup.lastItem.toolTip = [NSString stringWithFormat:@"%@\n\nTeam ID: %@\nCreated: %@\nExpires: %@\nStatus: %@",provision.name,provision.teamID,createDate,expiredDate,provision.status];
        }];
        return;
    }
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

- (void)initProvisionAndIdentityList {
    self.keychainsIdentities = [NSMutableArray array];
    self.provisioningMap = [NSMutableDictionary dictionary];
    
    NSArray *keychainsIdentities = [SigningIdentity keychainsIdenities];
    
    NSString *library = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *mobileProvisioningFolder = [library stringByAppendingPathComponent:@"MobileDevice/Provisioning Profiles"];
    NSDirectoryEnumerator *dirEnum = [self.fileManager enumeratorAtPath:mobileProvisioningFolder];
    
    NSMutableArray *provisionings = [NSMutableArray array];
    NSString *fineName;
    while ((fineName = [dirEnum nextObject]) != nil) {
        if ([fineName.pathExtension containsString:@"provision"]) {
            NSString *fullPath = [mobileProvisioningFolder stringByAppendingPathComponent:fineName];
            Provisioning *provisioning = [[Provisioning alloc] initWithPath:fullPath];
            [provisionings addObject:provisioning];
        }
    }
    
    for (SigningIdentity *keyhainsIdentity in keychainsIdentities) {
        NSMutableArray *matchedProvisions = [NSMutableArray array];
        [provisionings enumerateObjectsUsingBlock:^(Provisioning * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj containsSigningIdentity:keyhainsIdentity]) {
                [matchedProvisions addObject:obj];
            }
        }];
        [matchedProvisions sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
        if (matchedProvisions.count) {
            [self.keychainsIdentities addObject:keyhainsIdentity];
            [self.provisioningMap setValue:matchedProvisions forKey:keyhainsIdentity.serial];
        }
    }
}

- (void)controlsEnabled:(BOOL)enabled{
    
    if (![NSThread isMainThread]){
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self controlsEnabled:enabled];
        });
    }
    else{
        _isProcessing = !enabled;
        
        _codesigningCertsPopup.enabled = enabled;
        _inputField.enabled = enabled;
        _provisioningProfilesPopup.enabled = enabled;
        _entitlementField.enabled = enabled;
        _bundleIDField.enabled = enabled;
        _bundleVersionField.enabled = enabled;
        _shortVersionField.enabled = enabled;
        _scriptFileField.enabled = enabled;
        _urlSchemeField.enabled = enabled;
        _extraFileField.enabled = enabled;
        _displayNameField.enabled = enabled;
        
        _packIPAOption.enabled = enabled;
        _checkDecryptedOption.enabled = enabled;
        _disableASLROption.enabled = enabled;
        _removeRestrictOption.enabled = enabled;
        _enhancedModeOption.enabled = enabled;
        
        _selectInputButton.enabled = enabled;
        _refreshCertButton.enabled = enabled;
        _selectEntitlementButton.enabled = enabled;
        _startSignButton.enabled = enabled;
        _createScriptButton.enabled = enabled;
        _selectScriptButton.enabled = enabled;
    }
}

- (void)cleanup:(NSString *)tempFolder{
    NSLog(@"清理临时目录: %@",tempFolder);
    [_fileManager removeItemAtPath:tempFolder error:nil];
}

- (IBAction)onRefreshCert:(id)sender {
    [self loadProvisionAndIdentityList];
}

- (IBAction)onOpenProvision:(id)sender {
    NSString *library = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *mobileProvisioningFolder = [library stringByAppendingPathComponent:@"MobileDevice/Provisioning Profiles"];
    [[NSWorkspace sharedWorkspace] selectFile:nil inFileViewerRootedAtPath:mobileProvisioningFolder];
}

- (IBAction)onStartSign:(id)sender {
    
    if(![ShellExecute checkXcodeCLI]) {
//        [ShellExecute installXcodeCLI];
        NSAlert *alert = [[NSAlert alloc]init];
        alert.messageText = @"请安装 XCode 命令行工具，并重启应用";
        [alert runModal];
        [[NSApplication sharedApplication]terminate:self];
        return;
    }
    _outputInfo = nil;
    NSString *desktopPath = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES)[0];
    if (_inputPathList.count > 1) {
        [NSOpenPanel showOpenPanelModal:desktopPath message:@"选择保存文件的文件夹" fileTypes:nil multipleSelection:NO canChooseDirectories:YES canChooseFiles:NO canCreateDirectories:YES completionHandler:^(NSOpenPanel *panel, NSInteger result) {
            if (result == NSFileHandlingPanelOKButton) {
                _outputInfo = [[OutputInfo alloc]init];
                _outputInfo.path = panel.URL.path;
                _outputInfo.isDirectory = YES;
            }
        }];
    }
    else
    {
        // 修复文件直接拖入文件输入框或直接拷贝路径到输入框时导致的bug
        NSString *inputPath = self.inputField.stringValue;
        if (![_inputPathList.firstObject isEqualToString:inputPath]) {
            _inputPathList = [NSMutableArray array];
            [_inputPathList addObject:inputPath];
        }
        BOOL isDirectory;
        if ([self.fileManager fileExistsAtPath:inputPath isDirectory:&isDirectory]) {
            if (!isDirectory || [inputPath.pathExtension isEqualToString:@"app"]) {
                NSString *name = [[inputPath.lastPathComponent stringByDeletingPathExtension] stringByAppendingString:@"_resign"];
                if (self.packIPAOption.state) {
                    [NSSavePanel showSavePanelModal:name message:@"输入重签后的文件名" fileTypes:@[@"ipa"] canCreateDirectories:YES completionHandler:^(NSSavePanel *panel, NSInteger result) {
                        if (result == NSFileHandlingPanelOKButton) {
                            _outputInfo = [[OutputInfo alloc]init];
                            _outputInfo.path = panel.URL.path;
                            _outputInfo.isDirectory = NO;
                        }
                    }];
                }
                else{
                    [NSOpenPanel showOpenPanelModal:desktopPath message:@"选择保存文件的文件夹" fileTypes:nil multipleSelection:NO canChooseDirectories:YES canChooseFiles:NO canCreateDirectories:YES completionHandler:^(NSOpenPanel *panel, NSInteger result) {
                        if (result == NSFileHandlingPanelOKButton) {
                            _outputInfo = [[OutputInfo alloc]init];
                            _outputInfo.path = panel.URL.path;
                            _outputInfo.isDirectory = YES;
                        }
                    }];
                }
            }
            else
            {
                [NSOpenPanel showOpenPanelModal:desktopPath message:@"选择保存文件的文件夹" fileTypes:nil multipleSelection:NO canChooseDirectories:YES canChooseFiles:NO canCreateDirectories:YES completionHandler:^(NSOpenPanel *panel, NSInteger result) {
                    if (result == NSFileHandlingPanelOKButton) {
                        _outputInfo = [[OutputInfo alloc]init];
                        _outputInfo.path = panel.URL.path;
                        _outputInfo.isDirectory = YES;
                    }
                }];
            }
        }
    }
    
    if (_outputInfo.path.length) {
        self.signingIdentity = self.keychainsIdentities[self.codesigningCertsPopup.indexOfSelectedItem];
        if (!self.signingIdentity) {
            [self setStatus:@"未选择可签名的证书"];
            return;
        }
        self.applicationID = [self.bundleIDField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        self.displayName = [self.displayNameField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        self.shortVersion = [self.shortVersionField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];;
        self.bundleVersion = [self.bundleVersionField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        self.entitlementPlistFile = [self.entitlementField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        self.provisioningFile = nil;
        if (self.keychainsIdentities.count) {
            SigningIdentity *signingIdentity = [self.keychainsIdentities objectAtIndex:self.codesigningCertsPopup.indexOfSelectedItem];
            NSArray *provisions = [self.provisioningMap objectForKey:signingIdentity.serial];
            if (provisions.count) {
                self.provisioningFile = [provisions objectAtIndex:self.provisioningProfilesPopup.indexOfSelectedItem];
            }
        }
        self.specificFiles = nil;
        NSString *extraFile = [self.extraFileField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (extraFile.length) {
            self.specificFiles = [extraFile componentsSeparatedByString:@","];
        }
        self.urlSchemes = nil;
        NSString *urlSchemesString = [self.urlSchemeField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (urlSchemesString.length) {
            self.urlSchemes = [urlSchemesString componentsSeparatedByString:@","];
        }
        self.scriptFile = [self.scriptFileField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        self.packIPA = self.packIPAOption.state;
        self.checkDecrypted = self.checkDecryptedOption.state;
        self.disableASLR = self.disableASLROption.state;
        self.removeRestrict = self.removeRestrictOption.state;
        self.enhancedMode = self.enhancedModeOption.state;
        self.ignoreWarning = NO;
        
        [self controlsEnabled:NO];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self signingThread];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self controlsEnabled:YES];
            });
        });
    }
}

- (void)signingThread
{
    BOOL isDirectory = NO;
    for (NSString *path in self.inputPathList) {
        if ([self.fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
            if (isDirectory && ![[path.pathExtension lowercaseString] isEqualToString:@"app"]) {
                NSArray *files = [self.fileManager contentsOfDirectoryAtPath:path error:nil];
                for (NSString *file in files) {
                    if ([[file.pathExtension lowercaseString]isEqualToString:@"app"] || [[file.pathExtension lowercaseString]isEqualToString:@"ipa"]) {
                        NSString *subPath = [path stringByAppendingPathComponent:file];
                        [self preprocessFile:subPath];
                    }
                }
            }
            else
            {
                [self preprocessFile:path];
            }
        }
    }
}

- (BOOL)preprocessFile:(NSString *)inputFile
{
    NSString *tempFolder = [ShellExecute makeTempFolder];
    NSString *workingDirectory = [tempFolder stringByAppendingPathComponent:@"out"];
    NSString *payloadDirectory = [workingDirectory stringByAppendingPathComponent:@"Payload/"];
    
    if ([[inputFile.pathExtension lowercaseString] isEqualToString:@"ipa"]) {
        [self setStatus:@"解压 IPA 文件"];
        [self.fileManager createDirectoryAtPath:workingDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        if (![SSZipArchive unzipFileAtPath:inputFile toDestination:workingDirectory]) {
            [self setStatus:@"解压 IPA 文件失败"];
            return NO;
        }
    }
    else if ([[inputFile.pathExtension lowercaseString] isEqualToString:@"app"])
    {
        [self setStatus:@"拷贝 App 到 Payload 目录"];
        [self.fileManager createDirectoryAtPath:payloadDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        if (![self.fileManager copyItemAtPath:inputFile toPath:[payloadDirectory stringByAppendingPathComponent:inputFile.lastPathComponent] error:nil]) {
            [self setStatus:@"拷贝 App 到 Payload 目录失败"];
            return NO;
        }
    }
    
    // Loop through app bundles in payload directory
    NSArray *payloadFiles = [self.fileManager contentsOfDirectoryAtPath:payloadDirectory error:nil];
    for (NSString *fileName in payloadFiles) {
        NSString *appPath = [payloadDirectory stringByAppendingPathComponent:fileName];
        BOOL isDirectory;
        if (![self.fileManager fileExistsAtPath:appPath isDirectory:&isDirectory] || !isDirectory) {
            continue;
        }
        
        [self processFile:inputFile appBundlePath:appPath tempFolder:tempFolder workingDirectory:workingDirectory payloadDirectory:payloadDirectory];
    }
    //MARK: Cleanup
    [self cleanup:tempFolder];
    return YES;
}

- (BOOL)processFile:(NSString *)inputFile appBundlePath:(NSString *)appBundlePath tempFolder:(NSString *)tempFolder workingDirectory:(NSString *)workingDirectory payloadDirectory:(NSString *)payloadDirectory
{
    @autoreleasepool {
        do {
            
            if ([self.fileManager fileExistsAtPath:self.scriptFile]) {
                NSLog(@"执行自定义脚本函数 before");
                NSLog(@"------------------------------");
                RETaskOutput *output = [NSTask execute:@"/bin/bash" workingDirectory:nil arguments:@[self.scriptFile,@"before",inputFile,appBundlePath]];
                NSLog(@"%@",output.output);
                NSLog(@"------------------------------");
            }
            
            NSString *workingEntitlementsPlist = [tempFolder stringByAppendingPathComponent:@"Entitlements.plist"];
            NSString *appBundleInfoPlist = [appBundlePath stringByAppendingPathComponent:@"Info.plist"];
            NSString *appBundleProvisioningFilePath = [appBundlePath stringByAppendingPathComponent:@"embedded.mobileprovision"];
            
            NSMutableDictionary *appBundleInfoPlistDict = [NSMutableDictionary dictionaryWithContentsOfFile:appBundleInfoPlist];
            //MARK: Delete CFBundleResourceSpecification from Info.plist
            [appBundleInfoPlistDict removeObjectForKey:@"CFBundleResourceSpecification"];
            
            //MARK: Copy Provisioning Profile
            if(![self.fileManager fileExistsAtPath:self.provisioningFile.path]) {
                [self setStatus:@"重签需要的描述文件不存在"];
                break;
            }
            
            if ([self.fileManager fileExistsAtPath:appBundleProvisioningFilePath]) {
                [self setStatus:@"删除原描述文件 embedded.mobileprovision"];
                [self.fileManager removeItemAtPath:appBundleProvisioningFilePath error:nil];
            }
            [self setStatus:@"拷贝新的描述文件到 Bundle"];
            [self.fileManager copyItemAtPath:self.provisioningFile.path toPath:appBundleProvisioningFilePath error:nil];
            
            //MARK: Generate Entitlements.plist
            if(![self.fileManager fileExistsAtPath:self.entitlementPlistFile]) {
                [self setStatus:@"解析 Entitlements"];
                NSLog(@"------------------------------");
                NSLog(@"%@",self.provisioningFile.entitlements);
                NSLog(@"------------------------------");
                [self.provisioningFile.entitlements writeToFile:workingEntitlementsPlist atomically:YES];
            }
            
            //MARK: Change Application ID
            if (self.applicationID.length) {
                NSString *oldAppID = appBundleInfoPlistDict[@"CFBundleIdentifier"];
                BOOL (^changeAppexIDBlock)(NSString *path,BOOL isDirectory) = ^BOOL(NSString *appexFile,BOOL isDirectory){
                    NSString *appexPlist = [appexFile stringByAppendingPathComponent:@"Info.plist"];
                    // 修复微信改bundleid后安装失败问题
                    NSMutableDictionary *pluginInfoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:appexPlist];
                    NSString *appexBundleID = pluginInfoPlist[@"CFBundleIdentifier"];
                    if (appexBundleID.length) {
                        NSString *newAppexID = [appexBundleID stringByReplacingOccurrencesOfString:oldAppID withString:self.applicationID];
                        [self setStatus:@"修改 Appex %@ 的 App ID 为 %@",appexFile,newAppexID];
                        pluginInfoPlist[@"CFBundleIdentifier"] = newAppexID;
                    }
                    
                    if (pluginInfoPlist[@"WKCompanionAppBundleIdentifier"]) {
                        pluginInfoPlist[@"WKCompanionAppBundleIdentifier"] = self.applicationID;
                    }
                    
                    NSMutableDictionary *dictionaryArray = pluginInfoPlist[@"NSExtension"];
                    if (dictionaryArray) {
                        NSMutableDictionary *attributes = dictionaryArray[@"NSExtensionAttributes"];
                        NSString *wkAppBundleIdentifier = attributes[@"WKAppBundleIdentifier"];
                        NSString *newAppexID = [wkAppBundleIdentifier stringByReplacingOccurrencesOfString:oldAppID withString:self.applicationID];
                        attributes[@"WKAppBundleIdentifier"] = newAppexID;
                    }
                    
                    return [pluginInfoPlist writeToFile:appexPlist atomically:YES];
                };
                
                if (![NSFileManager recursiveDirectorySearch:appBundlePath extensions:@[@"app"] specificFiles:nil foundFileBlock:changeAppexIDBlock]) {
                    break;
                }
                if (![NSFileManager recursiveDirectorySearch:appBundlePath extensions:@[@"appex"] specificFiles:nil foundFileBlock:changeAppexIDBlock]) {
                    break;
                }
                
                [self setStatus:@"修改 App ID 为 %@",self.applicationID];
                appBundleInfoPlistDict[@"CFBundleIdentifier"] = self.applicationID;
            }
            
            //MARK: Change Display Name
            if(self.displayName.length) {
                [self setStatus:@"修改 Display Name 为 %@",self.displayName];
                appBundleInfoPlistDict[@"CFBundleDisplayName"] = self.displayName;
            }
            
            //MARK: Change Version
            if(self.bundleVersion.length) {
                [self setStatus:@"修改 Version 为 %@",self.bundleVersion];
                appBundleInfoPlistDict[@"CFBundleVersion"] = self.bundleVersion;
            }
            
            //MARK: Change Short Version
            if(self.shortVersion.length) {
                [self setStatus:@"修改 Short Version 为 %@",self.shortVersion];
                appBundleInfoPlistDict[@"CFBundleShortVersionString"] = self.shortVersion;
            }
            
            if (self.urlSchemes.count) {
                NSMutableArray *urlTypes = [appBundleInfoPlistDict[@"CFBundleURLTypes"] mutableCopy];
                NSDictionary *types = @{@"CFBundleTypeRole":@"Editor",@"CFBundleURLName":@"net.ymlab.dev.Replica",@"CFBundleURLSchemes":self.urlSchemes};
                [urlTypes addObject:types];
                appBundleInfoPlistDict[@"CFBundleURLTypes"] = urlTypes;
            }
            
            [appBundleInfoPlistDict writeToFile:appBundleInfoPlist atomically:YES];
            
            
            //MARK: Codesigning - General
            NSArray *signableExtensions = @[@"dylib",@"so",@"framework",@"appex",@"app"];
            
            BOOL (^signingBlock)(NSString *path,BOOL isDirectory) = ^BOOL(NSString *path,BOOL isDirectory){
                @autoreleasepool {
                    do {
                        NSString *executablePath = nil;
                        if (isDirectory) {
                            //MARK: Make sure that the executable is well... executable.
                            NSString *appexPlist = [path stringByAppendingPathComponent:@"Info.plist"];
                            NSMutableDictionary *pluginInfoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:appexPlist];
                            NSString *executableName = pluginInfoPlist[@"CFBundleExecutable"];
                            executablePath = [path stringByAppendingPathComponent:executableName];
                        }
                        else
                        {
                            executablePath = path;
                        }
                        
                        if (self.checkDecrypted && !isBinaryDecrypted(executablePath.UTF8String)) {
                            [self setStatus:@"文件还未解密 %@",path];
                            break;
                        }
                        
                        chmod(executablePath.UTF8String,0755);
                        
                        if(self.removeRestrict || self.disableASLR)
                        {
                            NSData *originalData = [NSData dataWithContentsOfFile:executablePath];
                            NSMutableData *binary = originalData.mutableCopy;
                            if (!binary) break;
                            
                            struct thin_header headers[4];
                            uint32_t numHeaders = 0;
                            headersFromBinary(headers, binary, &numHeaders);
                            
                            if (numHeaders == 0) {
                                [self setStatus:@"二进制文件中未找到兼容的架构"];
                                break;
                            }
                            
                            // Loop through all of the thin headers we found for each operation
                            for (uint32_t i = 0; i < numHeaders; i++) {
                                struct thin_header macho = headers[i];
                                if (self.removeRestrict) {
                                    if (!unrestrictBinary(binary, macho, NO)) {
                                        [self setStatus:@"没有找到可移除的 RESTRICT 段"];
                                    } else {
                                        [self setStatus:@"成功移除 RESTRICT 段"];
                                    }
                                }
                                
                                if (self.disableASLR) {
                                    [self setStatus:@"尝试移除 ASLR 标志"];
                                    if (removeASLRFromBinary(binary, macho)) {
                                        [self setStatus:@"成功移除 ASLR 标志"];
                                    }
                                }
                            }
                            
                            [binary writeToFile:executablePath atomically:YES];
                        }

                        BOOL success = [ShellExecute codesign:path certificate:self.signingIdentity.sha1 entitlements:workingEntitlementsPlist beforeBlock:^BOOL(NSString *file, NSString *certificate, NSString *entitlements) {
                            [self setStatus:@"签名文件 %@",[file stringByReplacingOccurrencesOfString:payloadDirectory withString:@""]];
                            return YES;
                        } afterBlock:^BOOL(NSString *file, NSString *certificate, NSString *entitlements, RETaskOutput *taskOutput) {
                            if (taskOutput.status != 0) {
                                NSString *filePath = [file stringByReplacingOccurrencesOfString:payloadDirectory withString:@""];
                                [self setStatus:@"签名失败 %@",filePath];
                                NSLog(@"错误详情 %@",taskOutput.output);
                                if (_ignoreWarning) {
                                    return YES;
                                }
                                __block BOOL fakeSuccess = NO;
                                BOOL isDecrypted = isBinaryDecrypted(filePath.UTF8String);
                                _semaphore = dispatch_semaphore_create(0);
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    NSAlert *alert = [[NSAlert alloc]init];
                                    [alert addButtonWithTitle:@"是"];
                                    [alert addButtonWithTitle:@"否"];
                                    alert.messageText = [NSString stringWithFormat:@"文件签名失败\n文件：%@\n状态：%@\n继续签名可能导致重签后的包出现闪退，是否继续？",[filePath lastPathComponent],isDecrypted?@"已解密":(@"未解密")];
                                    alert.informativeText = taskOutput.output;
                                    alert.alertStyle = NSWarningAlertStyle;
                                    alert.showsSuppressionButton = YES;
                                    NSModalResponse code = [alert runModal];
                                    _ignoreWarning = alert.suppressionButton.state;
                                    if (code == NSAlertFirstButtonReturn) {
                                        fakeSuccess = YES;
                                    }
                                    else
                                    {
                                        fakeSuccess = NO;
                                    }
                                    dispatch_semaphore_signal(_semaphore);
                                });
                                dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
                                
                                return fakeSuccess;
                            }
                            return YES;
                        }];
                        
                        return success;
                    } while (0);
                    
                    return NO;
                }
            };
            
            BOOL success = [NSFileManager recursiveDirectorySearch:appBundlePath findRuleBlock:^BOOL(NSString *path, BOOL isDirectory) {
                NSString *fileName = path.lastPathComponent;
                if ([signableExtensions containsObject:fileName.pathExtension] || [self.specificFiles containsObject:fileName])
                {
                    return YES;
                }
                
                if (self.enhancedMode && !isDirectory) {
                    return isMachOBinary(path.UTF8String);
                }
                
                return NO;
            } foundFileBlock:signingBlock];
            
            if (!success) {
                break;
            }
            
            if (!signingBlock(appBundlePath,YES)) {
                break;
            }
            
            //MARK: Codesigning - Verification
            RETaskOutput *verificationTask = [NSTask execute:@"/usr/bin/codesign" workingDirectory:nil arguments:@[@"-v",appBundlePath]];
            if(verificationTask.status != 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSAlert *alert = [[NSAlert alloc]init];
                    [alert addButtonWithTitle:@"好的"];
                    alert.messageText = @"应用签名校验失败";
                    alert.informativeText = verificationTask.output;
                    alert.alertStyle = NSCriticalAlertStyle;
                    [alert runModal];
                    [self setStatus:@"应用签名校验失败"];
                });
                break;
            }
            
            [self setStatus:@"应用签名校验成功"];
            
            //MARK: Packaging
            //Check if output already exists and delete
            BOOL isDirectory;
            if ([self.fileManager fileExistsAtPath:self.outputInfo.path isDirectory:&isDirectory]) {
                if (!isDirectory) {
                    [self.fileManager removeItemAtPath:self.outputInfo.path error:nil];
                }
            }
            else
            {
                if (self.outputInfo.isDirectory) {
                    [self.fileManager createDirectoryAtPath:self.outputInfo.path withIntermediateDirectories:YES attributes:nil error:nil];
                }
            }
            
            NSString *savePath = nil;
            if (self.outputInfo.isDirectory) {
                NSString *name = [[inputFile.lastPathComponent stringByDeletingPathExtension] stringByAppendingString:[NSString stringWithFormat:@"_resign.%@",self.packIPA?@"ipa":@"app"]];
                savePath = [self.outputInfo.path stringByAppendingPathComponent:name];
            }
            else
            {
                savePath = self.outputInfo.path;
            }
            
            if (self.packIPA) {
                [self setStatus:@"打包为 IPA"];
                if (![SSZipArchive createZipFileAtPath:savePath withContentsOfDirectory:workingDirectory]) {
                    [self setStatus:@"打包为 IPA 失败"];
                    break;
                }
            }
            else
            {
                [self setStatus:@"移动 app"];
                [self.fileManager moveItemAtPath:appBundlePath toPath:savePath error:nil];
            }
            
            [self setStatus:@"完成, 文件路径为 %@",savePath];
            
            if ([self.fileManager fileExistsAtPath:self.scriptFile]) {
                NSLog(@"执行自定义脚本函数 after");
                NSLog(@"------------------------------");
                RETaskOutput *output = [NSTask execute:@"/bin/bash" workingDirectory:nil arguments:@[self.scriptFile,@"after",inputFile,savePath]];
                NSLog(@"%@",output.output);
                NSLog(@"------------------------------");
            }
            
            return YES;
        } while (0);
        
        return NO;
    }
}

- (IBAction)onSelectInput:(id)sender {
    NSString *desktopPath = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES)[0];
    [NSOpenPanel showOpenPanelModal:desktopPath message:@"选择需要重签的文件或文件夹" fileTypes:@[@"ipa",@"app"] multipleSelection:YES canChooseDirectories:YES canChooseFiles:YES canCreateDirectories:NO completionHandler:^(NSOpenPanel *panel, NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            _inputPathList = [NSMutableArray array];
            for (NSURL *url in panel.URLs) {
                [_inputPathList addObject:url.path];
            }
            if (_inputPathList.count > 1) {
                _inputField.stringValue = [NSString stringWithFormat:@"%@ 等(%lu)个文件",_inputPathList[0],(unsigned long)_inputPathList.count];
            }
            else
            {
                _inputField.stringValue = _inputPathList[0];
            }
        }
    }];
}

- (IBAction)onSelectEntitlement:(id)sender {
    NSString *desktopPath = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES)[0];
    [NSOpenPanel showOpenPanelModal:desktopPath message:@"选择重签使用的权限文件" fileTypes:@[@"xml",@"plist"] multipleSelection:NO canChooseDirectories:NO canChooseFiles:YES canCreateDirectories:NO completionHandler:^(NSOpenPanel *panel, NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            _entitlementField.stringValue = [panel URL].path;
        }
    }];
}

- (IBAction)onSelectScript:(id)sender {
    NSString *desktopPath = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES)[0];
    [NSOpenPanel showOpenPanelModal:desktopPath message:@"选择需要使用的脚本文件" fileTypes:@[@"sh"] multipleSelection:NO canChooseDirectories:NO canChooseFiles:YES canCreateDirectories:NO completionHandler:^(NSOpenPanel *panel, NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            _scriptFileField.stringValue = [panel URL].path;
        }
    }];
}

- (IBAction)onCreateScript:(id)sender {
    [NSSavePanel showSavePanelModal:@"Template" message:@"选择需要保存脚本文件的目录" fileTypes:@[@"sh"] canCreateDirectories:YES completionHandler:^(NSSavePanel *panel, NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSString *resourcePath = [[NSBundle mainBundle]resourcePath];
            NSString *templatePath = [resourcePath stringByAppendingPathComponent:@"Template.sh"];
            [self.fileManager copyItemAtPath:templatePath toPath:[panel URL].path error:nil];
        }
    }];
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
            NSString *pathExtension = [[filePath pathExtension]lowercaseString];
            if ([@[@"ipa",@"app"] containsObject:pathExtension]) {
                _inputPathList = [NSMutableArray array];
                [_inputPathList addObject:filePath];
                _inputField.stringValue = filePath;
                return YES;
            }
            else if ([@[@"sh"] containsObject:pathExtension])
            {
                _scriptFileField.stringValue = filePath;
                return YES;
            }
            else if ([@[@"xml",@"plist"] containsObject:pathExtension])
            {
                _entitlementField.stringValue = filePath;
                return YES;
            }
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
            if ([@[@"ipa",@"app"] containsObject:pathExtension] ||
                [@[@"sh"] containsObject:pathExtension] ||
                [@[@"xml",@"plist"] containsObject:pathExtension]) {
                return NSDragOperationCopy;
            }
        }
    } while (0);
    
    return NSDragOperationNone;
}

@end
