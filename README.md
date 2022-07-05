## Replica

Replica 是 macOS 上一款强大的 IPA 重签工具。

自用工具，开发年代久远，代码有点乱，暂时没有重构计划，能用先用。

依赖`XCODE`工具链，因为需要用到`codesign`命令行工具进行签名。

主要功能：

* IPA重签名，支持批量处理，提高重签名效率。
* 支持重签时进行越狱包检测，防止非越狱包重签后闪退。
* 支持重签时禁用`ASLR`和移除`__RESTRICT`段。
* 支持增强模式签名，可以对安装包内所有二进制文件签名。
* 支持使用`shell`脚本来对签名过程做额外操作，比如注入动态库，修改资源等等。
* 支持快速查找应用内所有二进制文件。
* 支持快速查询应用签名证书的可用性。

## 截图
![QQ20190321-000792@2x.png](https://github.com/lemon4ex/Replica/blob/main/ScreenShot/QQ20190321-000792@2x.png)
![QQ20190321-000789@2x.png](https://github.com/lemon4ex/Replica/blob/main/ScreenShot/QQ20190321-000789%402x.png)
![QQ20190321-000790@2x.png](https://github.com/lemon4ex/Replica/blob/main/ScreenShot/QQ20190321-000790@2x.png)

## 感谢
* [ios-app-signer](https://github.com/DanTheMan827/ios-app-signer)
* [optool](https://github.com/alexzielenski/optool)
