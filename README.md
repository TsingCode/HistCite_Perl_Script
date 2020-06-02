# 反编译Histcite程序文件得到的Perl脚本
**声明：** 本人原创，全网首发，仅提供学习研究之用，切勿他用！

### 1. 使用 Resource Hacker 打开 HistCite.exe 文件，查看 Manifest 文件，可以判断出该软件是用 Perl 语言编写的。
![附图1](https://github.com/TsingCode/HistCite_Perl_Script/raw/master/images/1.jpg)
### 2. 通过火绒剑监控 Histcite 程序打开过程中的文件读写情况，可以判断该软件是利用 PDK 将 Perl 脚本编译成可执行文件的。
![附图2](https://github.com/TsingCode/HistCite_Perl_Script/raw/master/images/2.png)
### 3. 在网上找到一个脚本，可以实现 PDK 编译的 Perl 脚本的反编译：https://www.52pojie.cn/thread-445021-1-1.html
```shell
//writen by sunbeat
//2015-12-11
//decompile the PDK exe back to perl script

var BPNAME
var BPDECODE
var MEMSTART
var MEMEND
var size
var plname
var filename
var scriptaddr 
findmem "script",401000  //use script as the key word to search in memory
mov scriptaddr,$RESULT
eval "push 0x{scriptaddr}"
findcmd 401000,$RESULT   //find in instruction , where to call "script" memory address
mov BPNAME,$RESULT
mov BPDECODE,$RESULT+F
bp BPNAME
erun  //break in EAX is the name of perl script
bc BPNAME
eval [eax]
mov plname, $RESULT
bp BPDECODE
erun
bc BPDECODE
mov MEMSTART,eax  //eax stores the perl script's dump begin address
findmem #00#,eax  //from EAX as begin , until find 0x0 as the end
mov MEMEND,$RESULT
sub MEMEND,MEMSTART
mov size,MEMEND
eval "{plname}"
mov filename,$RESULT
DM MEMSTART,size,filename
itoa $RESULT,10.
mov size,$RESULT
eval "file:{filename} was writen {size} bytes"
msg $RESULT
reset  //ctrl+f2 , reload programe
ret
```
### 4. 用 HawkOD 软件打开 HistCite.exe 程序，右键点击 push ebp 那一行，在弹出的菜单中选择【运行脚本】，打开刚才下载的 decompile_perl.txt 脚本。
![附图3](https://github.com/TsingCode/HistCite_Perl_Script/raw/master/images/3.png)
### 5. 脚本执行成功，此时在脚本同目录下生产了一个名为 hist 的文件（没有后缀），直接修改文件名在后面加上后缀 .pl 即可用文本编辑器打开，在文本编辑器里可以看到自动格式化了的 Perl 脚本。
![附图4](https://github.com/TsingCode/HistCite_Perl_Script/raw/master/images/4.png)
